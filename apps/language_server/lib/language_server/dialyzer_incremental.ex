defmodule ElixirLS.LanguageServer.DialyzerIncremental do
  use GenServer
  alias ElixirLS.LanguageServer.{JsonRpc, Server}
  require Logger
  require Record
  alias ElixirLS.LanguageServer.Dialyzer.{Manifest, Analyzer}
  alias ElixirLS.LanguageServer.Dialyzer

  defstruct [
    :parent,
    :root_path,
    :analysis_pid,
    :warn_opts,
    :warning_format
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
  def handle_cast({:analyze, build_ref, warn_opts, warning_format}, state) do
    parent = self()

    {:ok, pid} =
      Task.start_link(fn ->
        warnings = do_analyze()
        send(parent, {:analysis_finished, warnings, build_ref})
      end)

    {:noreply, %{state | warn_opts: warn_opts, warning_format: warning_format}}
  end

  @impl GenServer
  def handle_info(
        {:analysis_finished, warnings_map, build_ref},
        state
      ) do
    diagnostics = to_diagnostics(warnings_map, state.warn_opts, state.warning_format)
    Server.dialyzer_finished(state.parent, diagnostics, build_ref)
    {:noreply, state}
  end

  defp do_analyze() do
    # TODO deps without app
    all_apps =
      Application.loaded_applications()
      |> Enum.map(&elem(&1, 0))
      |> Enum.map(&{&1, :code.lib_dir(&1)})
      # reject not loaded
      |> Enum.reject(fn {_app, res} -> match?({:error, :bad_name}, res) end)
      # reject elixir_ls
      |> Enum.reject(fn {app, _res} ->
        app in [
          :language_server,
          :elixir_ls_utils,
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

    warning_modules = Map.keys(warning_modules_to_apps)

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

    try do
      {us, {warnings, changed, analyzed}} =
        :timer.tc(fn ->
          Logger.info("Updating incremental PLT")
          :dialyzer.run_report_modules_changed_and_analyzed(opts)
        end)

      Logger.info(
        "Incremental PLT built in #{div(us, 1000)}ms changed #{length(changed)} modules, analyzed #{length(analyzed)}, #{length(warnings)} warnings found"
      )

      # warnings returned by dialyzer public api are stripped to https://www.erlang.org/doc/man/dialyzer#type-dial_warning
      # file paths are app relative but we need to know which umbrella app they come from
      # we load PLT info directly and read raw warnings
      {_dialyzer_plt, plt_info} =
        :dialyzer_iplt.plt_and_info_from_file(elixir_incremental_plt_path())

      iplt_info(warning_map: warning_map) = plt_info
      # filter by modules from project app/umbrella apps
      warning_map
      |> Map.take(warning_modules)
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
      :throw, {:dialyzer_error, message} ->
        IO.inspect(List.to_string(message))
        []

      kind, payload ->
        IO.inspect({kind, payload})
        []
    end
  end

  defp elixir_incremental_plt_path() do
    [
      File.cwd!(),
      ".elixir_ls/incremental-plt-elixir-ls-#{Manifest.otp_vsn()}_elixir-#{System.version()}"
    ]
    |> Path.join()
    |> to_charlist()
  end

  defp to_diagnostics(warnings_map, warn_opts, warning_format) do
    tags_enabled = Analyzer.matching_tags(warn_opts)

    apps_paths =
      if Mix.Project.umbrella?() do
        Mix.Project.apps_paths()
      else
        # in umbrella Mix.Project.apps_paths() returns nil
        # we add an empty prefix
        %{Mix.Project.config()[:app] => ""}
      end

    deduplicated_warnings =
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
end
