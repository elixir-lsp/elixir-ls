defmodule ElixirLS.LanguageServer.Dialyzer do
  alias ElixirLS.LanguageServer.{JsonRpc, Server}
  alias ElixirLS.LanguageServer.Dialyzer.{Manifest, Analyzer, Utils, SuccessTypings}
  import Utils
  use GenServer

  defstruct [
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
        {:error,
         "The current Erlang installation does not include Dialyzer. It may be available as a " <>
           "separate package."}

      not dialyzable?(System) ->
        {:error,
         "Dialyzer is disabled because core Elixir modules are missing debug info. " <>
           "You may need to recompile Elixir with Erlang >= OTP 20"}

      true ->
        :ok
    end
  end

  def start_link({parent, root_path}) do
    GenServer.start_link(__MODULE__, {parent, root_path}, name: {:global, {parent, __MODULE__}})
  end

  def analyze(parent \\ self(), build_ref, warn_opts, warning_format) do
    GenServer.cast(
      {:global, {parent, __MODULE__}},
      {:analyze, build_ref, warn_opts, warning_format}
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

  def suggest_contracts(server \\ {:global, {self(), __MODULE__}}, files) do
    GenServer.call(server, {:suggest_contracts, files}, :infinity)
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
    diagnostics = to_diagnostics(warnings, state.warn_opts, state.warning_format)

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
        if state.write_manifest_pid, do: Process.exit(state.write_manifest_pid, :kill)
        pid = Manifest.write(state.root_path, active_plt, mod_deps, md5, warnings, timestamp)
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
  def handle_cast({:analyze, build_ref, warn_opts, warning_format}, state) do
    state =
      ElixirLS.LanguageServer.Build.with_build_lock(fn ->
        if Mix.Project.get() do
          JsonRpc.log_message(:info, "[ElixirLS Dialyzer] Checking for stale beam files")
          new_timestamp = adjusted_timestamp()

          {removed_files, file_changes} =
            update_stale(state.md5, state.removed_files, state.file_changes, state.timestamp)

          state = %{
            state
            | warn_opts: warn_opts,
              timestamp: new_timestamp,
              removed_files: removed_files,
              file_changes: file_changes,
              build_ref: build_ref,
              warning_format: warning_format
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
    if reason != :normal do
      JsonRpc.show_message(
        :error,
        "ElixirLS Dialyzer had an error. If this happens repeatedly, set " <>
          "\"elixirLS.dialyzerEnabled\" to false in settings.json to disable it"
      )
    end
  end

  ## Helpers

  defp do_analyze(%{write_manifest_pid: write_manifest_pid} = state) do
    # Cancel writing to the manifest, since we'll end up overwriting it anyway
    if is_pid(write_manifest_pid), do: Process.exit(write_manifest_pid, :cancelled)

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

  defp update_stale(md5, removed_files, file_changes, timestamp) do
    prev_paths = Map.keys(md5) |> MapSet.new()

    # FIXME: Private API
    all_paths =
      Mix.Utils.extract_files([Mix.Project.build_path()], [:beam])
      |> Enum.map(&Path.relative_to_cwd(&1))
      |> MapSet.new()

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

        changed_contents =
          Task.async_stream(
            changed,
            fn file ->
              content = File.read!(file)
              {file, content, module_md5(file)}
            end,
            timeout: :infinity
          )
          |> Enum.into([])

        {changed, changed_contents}
      end)

    JsonRpc.log_message(
      :info,
      "[ElixirLS Dialyzer] Found #{length(changed)} changed files in #{div(us, 1000)} milliseconds"
    )

    file_changes =
      Enum.reduce(changed_contents, file_changes, fn {:ok, {file, content, hash}}, file_changes ->
        if is_nil(hash) or hash == md5[file] do
          Map.delete(file_changes, file)
        else
          Map.put(file_changes, file, {content, hash})
        end
      end)

    undialyzable = for {:ok, {file, _, nil}} <- changed_contents, do: file
    removed_files = Enum.uniq(removed_files ++ removed ++ (undialyzable -- changed))
    {removed_files, file_changes}
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
    Path.join([root_path, ".elixir_ls/dialyzer_tmp", file])
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
      build_ref: build_ref
    } = state

    {us, {active_plt, mod_deps, md5, warnings}} =
      :timer.tc(fn ->
        Task.async_stream(file_changes, fn {file, {content, _}} ->
          write_temp_file(root_path, file, content)
        end)
        |> Stream.run()

        for file <- removed_files do
          path = temp_file_path(root_path, file)

          case File.rm(path) do
            :ok ->
              :ok

            {:error, :enoent} ->
              :ok

            {:error, reason} ->
              IO.warn("Unable to remove temporary file #{path}: #{inspect(reason)}")
          end
        end

        temp_modules =
          for file <- Path.wildcard(temp_file_path(root_path, "**/*.beam")), into: %{} do
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
        JsonRpc.log_message(
          :info,
          "[ElixirLS Dialyzer] Analyzing #{Enum.count(modules_to_analyze)} modules: " <>
            "#{inspect(modules_to_analyze)}"
        )

        {active_plt, new_mod_deps, raw_warnings} = Analyzer.analyze(active_plt, files_to_analyze)

        mod_deps = update_mod_deps(mod_deps, new_mod_deps, removed_modules)
        warnings = add_warnings(warnings, raw_warnings)

        md5 =
          for {file, {_, hash}} <- file_changes, into: md5 do
            {file, hash}
          end

        md5 = remove_files(md5, removed_files)

        {active_plt, mod_deps, md5, warnings}
      end)

    JsonRpc.log_message(
      :info,
      "[ElixirLS Dialyzer] Analysis finished in #{div(us, 1000)} milliseconds"
    )

    analysis_finished(parent, :ok, active_plt, mod_deps, md5, warnings, timestamp, build_ref)
  end

  defp update_mod_deps(mod_deps, new_mod_deps, removed_modules) do
    mod_deps
    |> Map.merge(new_mod_deps)
    |> Map.drop(removed_modules)
    |> Map.new(fn {mod, deps} -> {mod, deps -- removed_modules} end)
  end

  defp remove_files(md5, removed_files) do
    Map.drop(md5, removed_files)
  end

  defp add_warnings(warnings, raw_warnings) do
    new_warnings =
      for {_, {file, line, m_or_mfa}, _} = warning <- raw_warnings,
          module = resolve_module(m_or_mfa),
          # Dialyzer warnings have the file path at the start of the app it's
          # in, which breaks umbrella apps. We have to manually resolve the file
          # from the module instead.
          file = resolve_module_file(module, file),
          in_project?(file) do
        {module, {file, line, warning}}
      end

    new_warnings
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.into(warnings)
  end

  defp resolve_module(module) when is_atom(module), do: module
  defp resolve_module({module, _, _}) when is_atom(module), do: module

  defp resolve_module_file(module, fallback) do
    # We try to resolve the module to its source file. The only time the source
    # info may not be available is when it has been stripped by the beam_lib
    # module, but that shouldn't be the case. More info:
    # http://erlang.org/doc/reference_manual/modules.html#module_info-0-and-module_info-1-functions
    module.module_info(:compile)
    |> Keyword.get(:source, fallback)
    |> Path.relative_to_cwd()
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

  defp in_project?(path) do
    File.exists?(path) and String.starts_with?(Path.absname(path), File.cwd!())
  end

  defp module_md5(file) do
    case :dialyzer_utils.get_core_from_beam(to_charlist(file)) do
      {:ok, core} ->
        core_bin = :erlang.term_to_binary(core)
        :crypto.hash(:md5, core_bin)

      {:error, _} ->
        nil
    end
  end

  defp to_diagnostics(warnings_map, warn_opts, warning_format) do
    tags_enabled = Analyzer.matching_tags(warn_opts)

    for {_beam_file, warnings} <- warnings_map,
        {source_file, line, data} <- warnings,
        {tag, _, _} = data,
        tag in tags_enabled,
        source_file = Path.absname(to_string(source_file)),
        in_project?(source_file),
        not String.starts_with?(source_file, Mix.Project.deps_path()) do
      %Mix.Task.Compiler.Diagnostic{
        compiler_name: "ElixirLS Dialyzer",
        file: source_file,
        position: line,
        message: warning_message(data, warning_format),
        severity: :warning,
        details: data
      }
    end
  end

  defp warning_message({_, _, {warning_name, args}} = raw_warning, warning_format)
       when warning_format in ["dialyxir_long", "dialyxir_short"] do
    format_function =
      case warning_format do
        "dialyxir_long" -> :format_long
        "dialyxir_short" -> :format_short
      end

    try do
      %{^warning_name => warning_module} = Dialyxir.Warnings.warnings()
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
    JsonRpc.log_message(
      :info,
      "[ElixirLS Dialyzer] Unrecognized dialyzerFormat setting: #{inspect(warning_format)}" <>
        ", falling back to \"dialyzer\""
    )

    dialyzer_raw_warning_message(raw_warning)
  end

  defp dialyzer_raw_warning_message(raw_warning) do
    message = String.trim(to_string(:dialyzer.format_warning(raw_warning)))
    Regex.replace(Regex.recompile!(~r/^.*:\d+: /), message, "")
  end

  # Because mtime-based stale-checking has 1-second granularity, we err on the side of
  # re-analyzing files that were compiled during the same second as the last analysis
  defp adjusted_timestamp do
    seconds = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    :calendar.gregorian_seconds_to_datetime(seconds - 1)
  end
end
