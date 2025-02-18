defmodule ElixirLS.LanguageServer.DialyzerIncremental do
  use GenServer
  alias ElixirLS.LanguageServer.{Server, JsonRpc, Diagnostics}
  require Logger
  require Record
  alias ElixirLS.LanguageServer.Dialyzer.{Manifest, Analyzer, SuccessTypings}
  alias ElixirLS.LanguageServer.Dialyzer

  defstruct [
    :parent,
    :root_path,
    :analysis_pid,
    :warn_opts,
    :warning_format,
    :apps_paths,
    :project_dir,
    :next_build,
    :plt
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

  def analyze(parent \\ self(), build_ref, warn_opts, warning_format, project_dir) do
    GenServer.cast(
      {:global, {parent, __MODULE__}},
      {:analyze, build_ref, warn_opts, warning_format, project_dir}
    )
  end

  def suggest_contracts(parent \\ self(), files)

  def suggest_contracts(_parent, []), do: []

  def suggest_contracts(parent, files) do
    try do
      GenServer.call({:global, {parent, __MODULE__}}, {:suggest_contracts, files}, :infinity)
    catch
      kind, payload ->
        {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
        error_msg = Exception.format(kind, payload, stacktrace)

        Logger.error("Unable to suggest contracts: #{error_msg}")
        []
    end
  end

  @impl GenServer
  def init({parent, root_path}) do
    state = %__MODULE__{parent: parent, root_path: root_path}

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        ElixirLS.LanguageServer.Server.do_sanity_check()
        message = Exception.format_exit(reason)

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => message
          },
          %{}
        )

        Logger.info("Terminating #{__MODULE__}: #{message}")

        JsonRpc.show_message(
          :error,
          "ElixirLS Dialyzer had an error. If this happens repeatedly, set " <>
            "\"elixirLS.dialyzerEnabled\" to false in settings.json to disable it"
        )
    end
  end

  @impl GenServer
  def handle_call({:suggest_contracts, files}, _from, state = %{plt: plt}) when plt != nil do
    specs =
      try do
        SuccessTypings.suggest_contracts(plt, files)
      catch
        :throw = kind, {:dialyzer_error, message} = payload ->
          {_payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)

          Logger.warning(
            "Unable to load incremental PLT: #{message}\n#{Exception.format_stacktrace(stacktrace)}"
          )

          []

        kind, payload ->
          {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)

          Logger.error(
            "Unexpected error during incremental PLT load: #{Exception.format(kind, payload, stacktrace)}"
          )

          []
      end

    {:reply, specs, state}
  end

  @impl GenServer
  def handle_cast(
        {:analyze, build_ref, warn_opts, warning_format, project_dir},
        %{analysis_pid: nil} = state
      ) do
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

          if state.plt do
            :dialyzer_plt.delete(state.plt)
          end

          {:ok, pid} =
            Task.start_link(fn ->
              {warnings, plt} = do_analyze(opts, warning_modules_to_apps)
              Manifest.transfer_plt(plt, parent)
              send(parent, {:analysis_finished, warnings, build_ref, plt})
            end)

          %{
            state
            | warn_opts: warn_opts,
              warning_format: warning_format,
              apps_paths: apps_paths,
              project_dir: project_dir,
              analysis_pid: pid,
              plt: nil
          }
        else
          state
        end
      end)

    {:noreply, state}
  end

  def handle_cast({:analyze, _build_ref, _warn_opts, _warning_format, _project_dir} = msg, state) do
    # analysis in progress - store last requested build
    # we will trigger one more time
    {:noreply, %{state | next_build: msg}}
  end

  @impl GenServer
  def handle_info(
        {:analysis_finished, warnings_map, build_ref, plt},
        state
      ) do
    diagnostics =
      to_diagnostics(
        warnings_map,
        state.warn_opts,
        state.warning_format,
        state.apps_paths,
        state.project_dir
      )

    Server.dialyzer_finished(state.parent, diagnostics, build_ref)
    state = %{state | analysis_pid: nil, plt: plt}

    case state.next_build do
      nil -> {:noreply, state}
      msg -> handle_cast(msg, %{state | next_build: nil})
    end
  end

  def handle_info(
        {:"ETS-TRANSFER", _, _, _},
        state
      ) do
    {:noreply, state}
  end

  defp build_dialyzer_opts() do
    # assume that all required apps has been loaded during build
    # notable exception is erts which is not loaded by default but we load it manually during startup
    loaded_apps =
      Application.loaded_applications()
      |> Enum.map(&elem(&1, 0))

    all_apps =
      loaded_apps
      |> Enum.map(&{&1, :code.lib_dir(&1)})
      # reject not loaded
      |> Enum.reject(fn {_app, res} -> match?({:error, :bad_name}, res) end)
      # reject elixir_ls
      |> Enum.reject(fn {app, _res} ->
        app in [
          :language_server,
          :debug_adapter,
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

    # we are under build lock - it's safe to call Mix.Project APIs
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
          module <- safe_get_modules(app),
          into: %{},
          do: {module, app}

    warning_files_rec =
      all_apps
      |> Keyword.filter(fn {app, _} -> app in warning_apps end)
      |> Keyword.values()
      |> Enum.map(&:filename.join(&1, ~c"ebin"))

    files_rec =
      unless :persistent_term.get(:language_server_test_mode, false) do
        files_rec
      else
        # do not include in PLT OTP and elixir apps in tests
        warning_files_rec
      end

    opts = [
      analysis_type: :incremental,
      files_rec: files_rec,
      warning_files_rec: warning_files_rec,
      from: :byte_code,
      init_plt: elixir_incremental_plt_path()
    ]

    {opts, warning_modules_to_apps}
  end

  defp safe_get_modules(app) do
    case :application.get_key(app, :modules) do
      {:ok, modules} -> modules
      :undefined -> []
    end
  end

  defp elixir_incremental_plt_path() do
    [
      File.cwd!(),
      ".elixir_ls/iplt-#{Manifest.otp_vsn()}_elixir-#{System.version()}-#{Mix.env()}"
    ]
    |> Path.join()
    |> to_charlist()
  end

  defp to_diagnostics(warnings_map, warn_opts, warning_format, apps_paths, project_dir) do
    tags_enabled = Analyzer.matching_tags(warn_opts)

    for {app, app_warnings_map} <- warnings_map,
        {_module, raw_warnings} <- app_warnings_map,
        {tag, {file, position, _m_or_mfa}, msg} <- raw_warnings,
        tag in tags_enabled,
        warning = {tag, {file, position}, msg},
        app_path = Map.fetch!(apps_paths, app),
        source_file = Path.absname(Path.join([app_path, to_string(file)]), project_dir) do
      %Diagnostics{
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
      {us, {dialyzer_plt, plt_info}} =
        :timer.tc(fn ->
          :dialyzer_iplt.plt_and_info_from_file(elixir_incremental_plt_path())
        end)

      Logger.info("Loaded PLT info in #{div(us, 1000)}ms")

      iplt_info(warning_map: warning_map) = plt_info
      # filter by modules from project app/umbrella apps
      warnings =
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

      {warnings, dialyzer_plt}
    catch
      :throw = kind, {:dialyzer_error, message} = payload ->
        {_payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)

        Logger.error(
          "Dialyzer error during incremental PLT build: #{message}\n#{Exception.format_stacktrace(stacktrace)}"
        )

        {[], nil}

      kind, payload ->
        {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)

        Logger.error(
          "Unexpected error during incremental PLT build: #{Exception.format(kind, payload, stacktrace)}"
        )

        {[], nil}
    end
  end
end
