defmodule ElixirLS.LanguageServer.DialyzerIncremental do
  use GenServer
  alias ElixirLS.LanguageServer.Server
  require Logger
  require Record
  alias ElixirLS.LanguageServer.Dialyzer.{Manifest, Analyzer}
  alias ElixirLS.LanguageServer.Dialyzer

  defstruct [
    :parent,
    :root_path,
    :analysis_pid,
    :warn_opts,
    :warning_format,
    :apps_paths,
    :next_build
  ]

  Record.defrecordp(:iplt_info, [
    :files,
    :mod_deps,
    :warning_map,
    :legal_warnings
  ])

  def start_link({parent, root_path}) do
    GenServer.start_link(__MODULE__, {parent, root_path}, name: {:global, {parent, __MODULE__}})
  end

  def analyze(parent \\ self(), build_ref, warn_opts, warning_format) do
    GenServer.cast(
      {:global, {parent, __MODULE__}},
      {:analyze, build_ref, warn_opts, warning_format}
    )
  end

  @impl GenServer
  def init({parent, root_path}) do
    state = %__MODULE__{parent: parent, root_path: root_path}

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:analyze, build_ref, warn_opts, warning_format}, %{analysis_pid: nil} = state) do
    state =
      ElixirLS.LanguageServer.Build.with_build_lock(fn ->
        if Mix.Project.get() do
          parent = self()

          apps_paths =
            if Mix.Project.umbrella?() do
              Mix.Project.apps_paths()
            else
              # in umbrella Mix.Project.apps_paths() returns nil
              # we add an empty prefix
              %{Mix.Project.config()[:app] => ""}
            end

          {opts, warning_modules_to_apps} = build_dialyzer_opts()

          {:ok, pid} =
            Task.start_link(fn ->
              warnings = do_analyze(opts, warning_modules_to_apps)
              send(parent, {:analysis_finished, warnings, build_ref})
            end)

          %{
            state
            | warn_opts: warn_opts,
              warning_format: warning_format,
              apps_paths: apps_paths,
              analysis_pid: pid
          }
        else
          state
        end
      end)

    {:noreply, state}
  end

  def handle_cast({:analyze, _build_ref, _warn_opts, _warning_format} = msg, state) do
    # analysis in progress - store last requested build
    # we will trigger one more time
    {:noreply, %{state | next_build: msg}}
  end

  @impl GenServer
  def handle_info(
        {:analysis_finished, warnings_map, build_ref},
        state
      ) do
    diagnostics =
      to_diagnostics(warnings_map, state.warn_opts, state.warning_format, state.apps_paths)

    Server.dialyzer_finished(state.parent, diagnostics, build_ref)
    state = %{state | analysis_pid: nil}

    case state.next_build do
      nil -> {:noreply, state}
      msg -> handle_cast(msg, %{state | next_build: nil})
    end
  end

  defp build_dialyzer_opts() do
    # assume that all required apps has been loaded during build
    # notable exception is erts which is not loaded by default
    loaded_apps =
      Application.loaded_applications()
      |> Enum.map(&elem(&1, 0))
      |> Kernel.++([:erts])

    all_apps =
      loaded_apps
      |> Enum.map(&{&1, :code.lib_dir(&1)})
      # reject not loaded
      |> Enum.reject(fn {_app, res} -> match?({:error, :bad_name}, res) end)
      # reject elixir_ls
      |> Enum.reject(fn {app, _res} ->
        app in [
          :language_server,
          :elixir_ls_debugger,
          :elixir_ls_utils,
          :mix_task_archive_deps,
          :jason_v,
          :dialyxir_vendored,
          :path_glob_vendored,
          :elixir_sense,
          :erl2ex
        ]
      end)
      # hex is distributed without debug info
      |> Enum.reject(fn {app, _res} -> app in [:hex] end)

    files_rec = all_apps |> Keyword.values() |> Enum.map(&:filename.join(&1, ~c"ebin"))

    warning_apps =
      if Mix.Project.umbrella?() do
        Mix.Project.apps_paths() |> Enum.map(&elem(&1, 0))
      else
        # in umbrella Mix.Project.apps_paths() returns nil
        # get app from config instead
        [Mix.Project.config()[:app]]
      end

    warning_modules_to_apps =
      for app <- warning_apps,
          {:ok, app_modules} = :application.get_key(app, :modules),
          module <- app_modules,
          into: %{},
          do: {module, app}

    warning_files_rec =
      all_apps
      |> Keyword.filter(fn {app, _} -> app in warning_apps end)
      |> Keyword.values()
      |> Enum.map(&:filename.join(&1, ~c"ebin"))

    opts = [
      analysis_type: :incremental,
      files_rec: files_rec,
      warning_files_rec: warning_files_rec,
      from: :byte_code,
      init_plt: elixir_incremental_plt_path()
    ]

    {opts, warning_modules_to_apps}
  end

  defp elixir_incremental_plt_path() do
    [
      File.cwd!(),
      ".elixir_ls/incremental-plt-elixir-ls-#{Manifest.otp_vsn()}_elixir-#{System.version()}"
    ]
    |> Path.join()
    |> to_charlist()
  end

  defp to_diagnostics(warnings_map, warn_opts, warning_format, apps_paths) do
    tags_enabled = Analyzer.matching_tags(warn_opts)

    for {app, app_warnings_map} <- warnings_map,
        {_module, raw_warnings} <- app_warnings_map,
        {tag, {file, position, _m_or_mfa}, msg} <- raw_warnings,
        tag in tags_enabled,
        warning = {tag, {file, position}, msg},
        app_path = Map.fetch!(apps_paths, app),
        source_file = Path.absname(Path.join([app_path, to_string(file)])) do
      %Mix.Task.Compiler.Diagnostic{
        compiler_name: "ElixirLS Dialyzer",
        file: source_file,
        position: Dialyzer.normalize_position(position),
        message: Dialyzer.warning_message(warning, warning_format),
        severity: :warning,
        details: warning
      }
    end
  end

  defp do_analyze(opts, warning_modules_to_apps) do
    try do
      {us, {warnings, changed, analyzed}} =
        :timer.tc(fn ->
          Logger.info("Updating incremental PLT")
          :dialyzer.run_report_modules_changed_and_analyzed(opts)
        end)

      changed_info =
        case changed do
          :undefined -> ""
          list -> "changed #{length(list)} modules, "
        end

      Logger.info(
        "Incremental PLT updated in #{div(us, 1000)}ms, #{changed_info}analyzed #{length(analyzed)}, #{length(warnings)} warnings found"
      )

      # warnings returned by dialyzer public api are stripped to https://www.erlang.org/doc/man/dialyzer#type-dial_warning
      # file paths are app relative but we need to know which umbrella app they come from
      # we load PLT info directly and read raw warnings
      {us, {_dialyzer_plt, plt_info}} =
        :timer.tc(fn ->
          :dialyzer_iplt.plt_and_info_from_file(elixir_incremental_plt_path())
        end)

      Logger.info("Loaded PLT info in #{div(us, 1000)}ms")

      iplt_info(warning_map: warning_map) = plt_info
      # filter by modules from project app/umbrella apps
      warning_map
      |> Map.take(Map.keys(warning_modules_to_apps))
      |> Enum.group_by(
        fn {module, _warnings} ->
          Map.fetch!(warning_modules_to_apps, module)
        end,
        fn {module, warnings} ->
          # raw warnings may be duplicated
          {module, Enum.uniq(warnings)}
        end
      )
    catch
      :throw = kind, {:dialyzer_error, message} = payload ->
        {_payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)

        Logger.error(
          "Dialyzer error during incremental PLT build: #{message}\n#{Exception.format_stacktrace(stacktrace)}"
        )

        []

      kind, payload ->
        {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)

        Logger.error(
          "Unexpected error during incremental PLT build: #{Exception.format(kind, payload, stacktrace)}"
        )

        []
    end
  end
end
