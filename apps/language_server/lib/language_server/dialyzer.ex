defmodule ElixirLS.LanguageServer.Dialyzer do
  alias ElixirLS.LanguageServer.{JsonRpc, Server, SourceFile, Diagnostics}
  alias ElixirLS.LanguageServer.Dialyzer.{Manifest, Analyzer, Utils, SuccessTypings}
  import Utils
  use GenServer
  require Logger

  defstruct [
    :project_dir,
    :deps_path,
    :parent,
    :timestamp,
    :plt,
    :root_path,
    :analysis_pid,
    :write_manifest_pid,
    :build_ref,
    :warning_format,
    warn_opts: [],
    mod_deps: %{},
    warnings: %{},
    file_changes: %{},
    removed_files: [],
    md5: %{},
    specs_cache: %{}
  ]

  # Client API

  def check_support do
    _ = String.to_integer(System.otp_release())
    {_compiled_with, _} = System.build_info() |> Map.fetch!(:otp_release) |> Integer.parse()

    cond do
      not Code.ensure_loaded?(:dialyzer) ->
        # TODO is this check relevant? We check for dialyzer app in CLI
        {:error, :no_dialyzer,
         "The current Erlang installation does not include Dialyzer. It may be available as a " <>
           "separate package."}

      not dialyzable?(System) ->
        # TODO is this relevant anymore? We require OTP 22+ (minimum for elixir 1.13)
        {:error, :no_debug_info,
         "Dialyzer is disabled because core Elixir modules are missing debug info. " <>
           "You may need to recompile Elixir with Erlang >= OTP 20"}

      true ->
        :ok
    end
  end

  def start_link({parent, root_path}) do
    GenServer.start_link(__MODULE__, {parent, root_path}, name: {:global, {parent, __MODULE__}})
  end

  def analyze(parent \\ self(), build_ref, warn_opts, warning_format, project_dir) do
    GenServer.cast(
      {:global, {parent, __MODULE__}},
      {:analyze, build_ref, warn_opts, warning_format, project_dir}
    )
  end

  def analysis_finished(server, status, active_plt, mod_deps, md5, warnings, timestamp, build_ref) do
    GenServer.call(
      server,
      {
        :analysis_finished,
        status,
        active_plt,
        mod_deps,
        md5,
        warnings,
        timestamp,
        build_ref
      },
      :infinity
    )
  end

  def suggest_contracts(server \\ {:global, {self(), __MODULE__}}, files)

  def suggest_contracts(_server, []), do: []

  def suggest_contracts(server, files) do
    try do
      GenServer.call(server, {:suggest_contracts, files}, :infinity)
    catch
      kind, payload ->
        {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
        error_msg = Exception.format(kind, payload, stacktrace)

        Logger.error("Unable to suggest contracts: #{error_msg}")
        []
    end
  end

  # Server callbacks

  @impl GenServer
  def init({parent, root_path}) do
    state = %__MODULE__{parent: parent, root_path: root_path}

    state =
      case Manifest.read(root_path) do
        {:ok, active_plt, mod_deps, md5, warnings, timestamp} ->
          %{
            state
            | plt: active_plt,
              mod_deps: mod_deps,
              md5: md5,
              warnings: warnings,
              timestamp: timestamp
          }

        :error ->
          {:ok, pid} = Manifest.build_new_manifest()
          %{state | analysis_pid: pid}
      end

    {:ok, state}
  end

  @impl GenServer
  def handle_call(
        {:analysis_finished, _status, active_plt, mod_deps, md5, warnings, timestamp, build_ref},
        _from,
        state
      ) do
    diagnostics =
      to_diagnostics(
        warnings,
        state.warn_opts,
        state.warning_format,
        state.project_dir,
        state.deps_path
      )

    Server.dialyzer_finished(state.parent, diagnostics, build_ref)

    state = %{
      state
      | plt: active_plt,
        mod_deps: mod_deps,
        md5: md5,
        warnings: warnings,
        analysis_pid: nil
    }

    state =
      if not is_nil(state.build_ref) do
        do_analyze(state)
      else
        maybe_cancel_write_manifest(state)

        {:ok, pid} =
          Manifest.write(state.root_path, active_plt, mod_deps, md5, warnings, timestamp)

        %{state | write_manifest_pid: pid}
      end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:suggest_contracts, files}, _from, %{plt: plt} = state) do
    specs = if is_nil(plt), do: [], else: SuccessTypings.suggest_contracts(plt, files)
    {:reply, specs, state}
  end

  @impl GenServer
  def handle_cast({:analyze, build_ref, warn_opts, warning_format, project_dir}, state) do
    state =
      ElixirLS.LanguageServer.Build.with_build_lock(fn ->
        # we can safely access Mix.Project under build lock
        if Mix.Project.get() do
          Logger.info("[ElixirLS Dialyzer] Checking for stale beam files")
          deps_path = Mix.Project.deps_path()
          build_path = Mix.Project.build_path()

          new_timestamp = adjusted_timestamp()

          {removed_files, file_changes} =
            update_stale(
              state.md5,
              state.removed_files,
              state.file_changes,
              state.timestamp,
              project_dir,
              build_path
            )

          state = %{
            state
            | warn_opts: warn_opts,
              timestamp: new_timestamp,
              removed_files: removed_files,
              file_changes: file_changes,
              build_ref: build_ref,
              warning_format: warning_format,
              project_dir: project_dir,
              deps_path: deps_path
          }

          trigger_analyze(state)
        else
          state
        end
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:"ETS-TRANSFER", _, _, _}, state) do
    {:noreply, state}
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

  ## Helpers

  defp do_analyze(state) do
    # Cancel writing to the manifest, since we'll end up overwriting it anyway
    maybe_cancel_write_manifest(state)

    parent = self()
    analysis_pid = spawn_link(fn -> compile(parent, state) end)

    %{
      state
      | analysis_pid: analysis_pid,
        write_manifest_pid: nil,
        file_changes: %{},
        removed_files: [],
        build_ref: nil
    }
  end

  defp trigger_analyze(%{analysis_pid: nil} = state), do: do_analyze(state)
  defp trigger_analyze(state), do: state

  defp update_stale(md5, removed_files, file_changes, timestamp, project_dir, build_path) do
    prev_paths = Map.keys(md5) |> MapSet.new()

    # FIXME: Private API
    all_paths =
      for path <- Mix.Utils.extract_files([build_path], [:beam]),
          into: MapSet.new(),
          do: Path.relative_to(path, project_dir)

    removed =
      prev_paths
      |> MapSet.difference(all_paths)
      |> MapSet.to_list()

    new_paths =
      all_paths
      |> MapSet.difference(prev_paths)
      |> MapSet.to_list()

    {us, {changed, changed_contents}} =
      :timer.tc(fn ->
        changed =
          all_paths
          |> extract_stale(timestamp)
          |> Enum.concat(new_paths)
          |> Enum.uniq()

        changed_contents = get_changed_files_contents(changed)

        {changed, changed_contents}
      end)

    Logger.info(
      "[ElixirLS Dialyzer] Found #{length(changed)} changed files in #{div(us, 1000)} milliseconds"
    )

    file_changes =
      Enum.reduce(changed_contents, file_changes, fn
        {:ok, {file, content, hash}}, file_changes ->
          if is_nil(hash) or hash == md5[file] do
            Map.delete(file_changes, file)
          else
            Map.put(file_changes, file, {content, hash})
          end

        {:exit, reason}, file_changes ->
          # on elixir >= 1.14 reason will actually be {beam_path, reason}

          message = "Unable to process one of the beams: #{Exception.format_exit(reason)}"
          Logger.error(message)

          case reason do
            {beam_path, _inner_reason} when is_binary(beam_path) or is_list(beam_path) ->
              case File.rm_rf(beam_path) do
                {:ok, _} ->
                  Logger.info("Beam file #{inspect(beam_path)} removed")
                  :ok

                rm_error ->
                  Logger.warning(
                    "Unable to remove beam file #{inspect(beam_path)}: #{inspect(rm_error)}"
                  )

                  JsonRpc.show_message(
                    :error,
                    "ElixirLS Dialyzer is unable to process #{inspect(beam_path)}. Please remove it manually"
                  )
              end

            _ ->
              JsonRpc.show_message(
                :error,
                "ElixirLS Dialyzer is unable to process one of the beam files. Please remove .elixir_ls/dialyzer* directory manually"
              )

              :ok
          end

          file_changes
      end)

    undialyzable = for {:ok, {file, _, nil}} <- changed_contents, do: file
    removed_files = Enum.uniq(removed_files ++ removed ++ (undialyzable -- changed))
    {removed_files, file_changes}
  end

  defp get_changed_files_contents(changed) do
    with_trapping_exits(fn ->
      # TODO remove if when we require elixir 1.14
      task_options =
        if Version.match?(System.version(), ">= 1.14.0-dev") do
          [zip_input_on_exit: true]
        else
          []
        end
        |> Keyword.put(:timeout, :infinity)

      Task.async_stream(
        changed,
        fn file ->
          content = File.read!(file)
          {file, content, module_md5(file)}
        end,
        task_options
      )
      |> Enum.into([])
    end)
  end

  defp extract_stale(sources, timestamp) do
    for source <- sources,
        last_modified(source) > timestamp do
      source
    end
  end

  defp last_modified(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mtime: mtime}} ->
        mtime

      {:error, _} ->
        {0, 0}
    end
  end

  defp temp_file_path(root_path, file) do
    Path.join([
      root_path,
      ".elixir_ls/dialyzer_#{System.otp_release()}_#{System.version()}_tmp",
      file
    ])
  end

  defp write_temp_file(root_path, file_path, content) do
    tmp_path = temp_file_path(root_path, file_path)
    File.mkdir_p!(Path.dirname(tmp_path))
    File.write!(tmp_path, content)
  end

  defp compile(parent, state) do
    %{
      root_path: root_path,
      plt: active_plt,
      mod_deps: mod_deps,
      md5: md5,
      warnings: warnings,
      timestamp: timestamp,
      removed_files: removed_files,
      file_changes: file_changes,
      build_ref: build_ref,
      project_dir: project_dir
    } = state

    {us, {active_plt, mod_deps, md5, warnings}} =
      :timer.tc(fn ->
        with_trapping_exits(fn ->
          Task.async_stream(file_changes, fn {file, {content, _}} ->
            write_temp_file(root_path, file, content)
          end)
          |> Stream.run()
        end)

        for file <- removed_files do
          path = temp_file_path(root_path, file)

          case File.rm(path) do
            :ok ->
              :ok

            {:error, :enoent} ->
              :ok

            {:error, reason} ->
              Logger.warning(
                "[ElixirLS Dialyzer] Unable to remove temporary file #{path}: #{inspect(reason)}"
              )
          end
        end

        temp_modules =
          for file <-
                Path.wildcard(
                  temp_file_path(SourceFile.Path.escape_for_wildcard(root_path), "**/*.beam")
                ),
              into: %{} do
            {String.to_atom(Path.basename(file, ".beam")), to_charlist(file)}
          end

        prev_modules = MapSet.new(:sets.to_list(:dialyzer_plt.all_modules(active_plt)))
        changed_modules = Enum.map(Map.keys(file_changes), &pathname_to_module/1)
        removed_modules = Enum.map(removed_files, &pathname_to_module/1)

        unchanged_modules =
          MapSet.difference(prev_modules, MapSet.new(changed_modules ++ removed_modules))

        stale_modules = dependent_modules(changed_modules ++ removed_modules, mod_deps)

        # Remove modules that need analysis from mod_deps and PLT
        mod_deps = Map.drop(mod_deps, MapSet.to_list(stale_modules))
        for module <- stale_modules, do: :dialyzer_plt.delete_module(active_plt, module)

        # For changed modules, we look at erlang AST to find referenced modules that aren't analyzed
        referenced_modules = expand_references(changed_modules, unchanged_modules)

        modules_to_analyze =
          MapSet.union(stale_modules, referenced_modules) |> Enum.filter(&dialyzable?/1)

        files_to_analyze =
          for module <- modules_to_analyze do
            temp_modules[module] || Utils.get_beam_file(module)
          end

        # Clear warnings for files that changed or need to be re-analyzed
        warnings = Map.drop(warnings, modules_to_analyze)

        # Analyze!
        Logger.info(
          "[ElixirLS Dialyzer] Analyzing #{Enum.count(modules_to_analyze)} modules: " <>
            "#{inspect(modules_to_analyze)}"
        )

        {active_plt, new_mod_deps, raw_warnings} = Analyzer.analyze(active_plt, files_to_analyze)

        mod_deps = update_mod_deps(mod_deps, new_mod_deps, removed_modules)
        warnings = add_warnings(warnings, raw_warnings, project_dir)

        md5 = Map.drop(md5, removed_files)

        md5 =
          for {file, {_, hash}} <- file_changes, into: md5 do
            {file, hash}
          end

        {active_plt, mod_deps, md5, warnings}
      end)

    Logger.info("[ElixirLS Dialyzer] Analysis finished in #{div(us, 1000)} milliseconds")

    JsonRpc.telemetry("dialyzer", %{}, %{"elixir_ls.dialyzer_time" => div(us, 1000)})

    analysis_finished(parent, :ok, active_plt, mod_deps, md5, warnings, timestamp, build_ref)
  end

  defp update_mod_deps(mod_deps, new_mod_deps, removed_modules) do
    for {mod, deps} <- mod_deps,
        mod not in removed_modules,
        into: new_mod_deps do
      {mod, deps -- removed_modules}
    end
  end

  defp add_warnings(warnings, raw_warnings, project_dir) do
    new_warnings =
      for {_, {file, line, m_or_mfa}, _} = warning <- raw_warnings,
          module = resolve_module(m_or_mfa),
          # Dialyzer warnings have the file path at the start of the app it's
          # in, which breaks umbrella apps. We have to manually resolve the file
          # from the module instead.
          file = resolve_module_file(module, file, project_dir),
          in_project?(SourceFile.Path.absname(file, project_dir), project_dir) do
        {module, {file, line, warning}}
      end

    new_warnings
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.into(warnings)
  end

  defp resolve_module(module) when is_atom(module), do: module
  defp resolve_module({module, _, _}) when is_atom(module), do: module

  defp resolve_module_file(module, fallback, project_dir) do
    # We try to resolve the module to its source file. The only time the source
    # info may not be available is when it has been stripped by the beam_lib
    # module, but that shouldn't be the case. More info:
    # http://erlang.org/doc/reference_manual/modules.html#module_info-0-and-module_info-1-functions
    if Code.ensure_loaded?(module) do
      module.module_info(:compile)
      |> Keyword.get(:source, fallback)
      |> Path.relative_to(project_dir)
    else
      # In case the file fails to load return fallback
      Path.relative_to(fallback, project_dir)
    end
  end

  defp dependent_modules(modules, mod_deps, result \\ MapSet.new())

  defp dependent_modules([], _, result) do
    result
  end

  defp dependent_modules([module | rest], mod_deps, result) do
    if module in result do
      result
    else
      result = MapSet.put(result, module)
      deps = Map.get(mod_deps, module, [])
      dependent_modules(deps ++ rest, mod_deps, result)
    end
  end

  defp in_project?(path, project_dir) do
    # path and project_dir is absolute path with universal separators
    File.exists?(path) and SourceFile.Path.path_in_dir?(path, project_dir)
  end

  defp module_md5(file) do
    case :dialyzer_utils.get_core_from_beam(to_charlist(file)) do
      {:ok, core} ->
        core_bin = :erlang.term_to_binary(core)
        :crypto.hash(:md5, core_bin)

      {:error, reason} ->
        Logger.warning(
          "[ElixirLS Dialyzer] get_core_from_beam failed for #{file}: #{inspect(reason)}"
        )

        nil
    end
  end

  defp to_diagnostics(warnings_map, warn_opts, warning_format, project_dir, deps_path) do
    tags_enabled = Analyzer.matching_tags(warn_opts)

    for {_beam_file, warnings} <- warnings_map,
        {source_file, position, data} <- warnings,
        {tag, _, _} = data,
        tag in tags_enabled,
        source_file = SourceFile.Path.absname(to_string(source_file), project_dir),
        in_project?(source_file, project_dir),
        not SourceFile.Path.path_in_dir?(source_file, deps_path) do
      %Diagnostics{
        compiler_name: "ElixirLS Dialyzer",
        file: source_file,
        position: normalize_postion(position),
        message: warning_message(data, warning_format),
        severity: :warning,
        details: data
      }
    end
  end

  # up until OTP 23 position was line :: non_negative_integer
  # starting from OTP 24 it is erl_anno:location() :: line | {line, column}
  defp normalize_postion({line, column}) when line > 0 do
    {line, column}
  end

  # 0 means unknown line
  defp normalize_postion(line) when line >= 0 do
    line
  end

  defp normalize_postion(position) do
    Logger.warning(
      "[ElixirLS Dialyzer] dialyzer returned warning with invalid position #{inspect(position)}"
    )

    0
  end

  defp warning_message({_, _, {warning_name, args}} = raw_warning, warning_format)
       when warning_format in ["dialyxir_long", "dialyxir_short"] do
    format_function =
      case warning_format do
        "dialyxir_long" -> :format_long
        "dialyxir_short" -> :format_short
      end

    try do
      %{^warning_name => warning_module} = DialyxirVendored.Warnings.warnings()
      <<_::binary>> = apply(warning_module, format_function, [args])
    rescue
      _ -> warning_message(raw_warning, "dialyzer")
    catch
      _ -> warning_message(raw_warning, "dialyzer")
    end
  end

  defp warning_message(raw_warning, "dialyzer") do
    dialyzer_raw_warning_message(raw_warning)
  end

  defp warning_message(raw_warning, warning_format) do
    Logger.info(
      "[ElixirLS Dialyzer] Unrecognized dialyzerFormat setting: #{inspect(warning_format)}" <>
        ", falling back to \"dialyzer\""
    )

    dialyzer_raw_warning_message(raw_warning)
  end

  defp dialyzer_raw_warning_message(raw_warning) do
    message = String.trim(to_string(:dialyzer.format_warning(raw_warning)))
    Regex.replace(~r/^.*:\d+: /u, message, "")
  end

  # Because mtime-based stale-checking has 1-second granularity, we err on the side of
  # re-analyzing files that were compiled during the same second as the last analysis
  defp adjusted_timestamp do
    seconds = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    :calendar.gregorian_seconds_to_datetime(seconds - 1)
  end

  defp maybe_cancel_write_manifest(%{write_manifest_pid: nil}), do: :ok

  defp maybe_cancel_write_manifest(%{write_manifest_pid: pid}) do
    Process.unlink(pid)
    Process.exit(pid, :kill)
  end

  defp with_trapping_exits(fun) do
    Process.flag(:trap_exit, true)
    fun.()
  after
    Process.flag(:trap_exit, false)
  end
end
