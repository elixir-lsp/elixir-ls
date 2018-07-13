defmodule ElixirLS.LanguageServer.Dialyzer do
  alias ElixirLS.LanguageServer.{JsonRpc, Server}
  alias ElixirLS.LanguageServer.Dialyzer.{Manifest, Analyzer, Utils}
  import Utils
  require Logger
  use GenServer

  defstruct [
    :parent,
    :timestamp,
    :plt,
    :root_path,
    :analysis_pid,
    :write_manifest_pid,
    needs_analysis?: false,
    warn_opts: [],
    mod_deps: %{},
    warnings: %{},
    file_changes: %{},
    removed_files: [],
    md5: %{}
  ]

  # Client API

  def check_support do
    otp_release = String.to_integer(System.otp_release())

    cond do
      otp_release < 20 ->
        {:error,
         "Dialyzer integration requires Erlang OTP 20 or higher (Currently OTP #{otp_release})"}

      not File.regular?(Manifest.elixir_plt_path()) and not dialyzable?(System) ->
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

  def analyze(parent \\ self(), warn_opts) do
    GenServer.call({:global, {parent, __MODULE__}}, {:analyze, warn_opts}, :infinity)
  end

  def analysis_finished(server, status, active_plt, mod_deps, md5, warnings, timestamp) do
    GenServer.call(
      server,
      {
        :analysis_finished,
        status,
        active_plt,
        mod_deps,
        md5,
        warnings,
        timestamp
      },
      :infinity
    )
  end

  # Server callbacks

  def init({parent, root_path}) do
    state = %__MODULE__{parent: parent, root_path: root_path}

    state =
      case Manifest.read(root_path) do
        {:ok, active_plt, mod_deps, md5, warnings, timestamp} ->
          state = %{
            state
            | plt: active_plt,
              mod_deps: mod_deps,
              md5: md5,
              warnings: warnings,
              timestamp: timestamp
          }

          trigger_analyze(state)

        :error ->
          %{state | analysis_pid: Manifest.build_new_manifest()}
      end

    {:ok, state}
  end

  def handle_call(
        {:analysis_finished, _status, active_plt, mod_deps, md5, warnings, timestamp},
        _from,
        state
      ) do
    diagnostics = to_diagnostics(warnings, state.warn_opts)
    Server.dialyzer_finished(state.parent, {:ok, diagnostics})

    state = %{
      state
      | plt: active_plt,
        mod_deps: mod_deps,
        md5: md5,
        warnings: warnings,
        analysis_pid: nil
    }

    state =
      if state.needs_analysis? do
        do_analyze(state)
      else
        if state.write_manifest_pid, do: Process.exit(state.write_manifest_pid, :kill)
        pid = Manifest.write(state.root_path, active_plt, mod_deps, md5, warnings, timestamp)
        %{state | write_manifest_pid: pid}
      end

    {:reply, :ok, state}
  end

  def handle_call({:analyze, warn_opts}, _from, state) do
    state =
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
            file_changes: file_changes
        }

        trigger_analyze(state)
      else
        state
      end

    {:reply, :ok, state}
  end

  def handle_info({:"ETS-TRANSFER", _, _, _}, state) do
    {:noreply, state}
  end

  def handle_info(msg, state) do
    super(msg, state)
  end

  def terminate(reason, state) do
    if reason != :normal do
      JsonRpc.show_message(
        :error,
        "ElixirLS Dialyzer had an error. If this happens repeatedly, set " <>
          "\"elixirLS.dialyzerEnabled\" to false in settings.json to disable it"
      )
    end

    super(reason, state)
  end

  ## Helpers

  defp do_analyze(state) do
    parent = self()
    analysis_pid = spawn_link(fn -> compile(parent, state) end)

    %{
      state
      | analysis_pid: analysis_pid,
        file_changes: %{},
        removed_files: [],
        needs_analysis?: false
    }
  end

  defp trigger_analyze(%{analysis_pid: nil} = state) do
    do_analyze(state)
  end

  defp trigger_analyze(state) do
    put_in(state.needs_analysis?, true)
  end

  defp update_stale(md5, removed_files, file_changes, timestamp) do
    prev_paths = MapSet.new(Map.keys(md5))

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

    changed = Enum.uniq(new_paths ++ Mix.Utils.extract_stale(all_paths, [timestamp]))

    changed_contents =
      Task.async_stream(changed, fn file ->
        content = File.read!(file)
        {file, content, module_md5(file)}
      end)
      |> Enum.into([])

    file_changes =
      Enum.reduce(changed_contents, file_changes, fn {:ok, {file, content, hash}}, file_changes ->
        if is_nil(hash) or hash == md5[file] do
          Map.delete(file_changes, file)
        else
          Map.put(file_changes, file, {content, hash})
        end
      end)

    undialyzable = for {:ok, {file, _, nil}} <- changed_contents, do: file
    removed_files = Enum.uniq(removed_files ++ removed ++ undialyzable -- changed)
    {removed_files, file_changes}
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
      file_changes: file_changes
    } = state

    {us, {active_plt, mod_deps, md5, warnings, timestamp}} =
      :timer.tc(fn ->
        Task.async_stream(file_changes, fn {file, {content, _}} ->
          write_temp_file(root_path, file, content)
        end)
        |> Stream.run()

        for file <- removed_files do
          File.rm(temp_file_path(root_path, file))
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
        mod_deps = Map.drop(mod_deps, stale_modules)
        for module <- stale_modules, do: :dialyzer_plt.delete_module(active_plt, module)

        # For changed modules, we look at erlang AST to find referenced modules that aren't analyzed
        referenced_modules = expand_references(changed_modules, unchanged_modules)

        modules_to_analyze =
          MapSet.union(stale_modules, referenced_modules) |> Enum.filter(&dialyzable?/1)

        files_to_analyze =
          for module <- modules_to_analyze do
            temp_modules[module] || :code.which(module)
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

        mod_deps = Map.merge(mod_deps, new_mod_deps)
        warnings = add_warnings(warnings, raw_warnings)

        md5 =
          for {file, {_, hash}} <- file_changes, into: md5 do
            {file, hash}
          end

        {active_plt, mod_deps, md5, warnings, timestamp}
      end)

    JsonRpc.log_message(
      :info,
      "[ElixirLS Dialyzer] Analysis finished in #{div(us, 1000)} milliseconds"
    )

    analysis_finished(parent, :ok, active_plt, mod_deps, md5, warnings, timestamp)
  end

  defp add_warnings(warnings, raw_warnings) do
    new_warnings =
      for {_, {file, line, m_or_mfa}, _} = warning <- raw_warnings, in_project?(file) do
        module =
          case m_or_mfa do
            module when is_atom(module) -> module
            {module, _, _} when is_atom(module) -> module
          end

        {module, {file, line, warning}}
      end

    new_warnings
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.into(warnings)
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

  defp to_diagnostics(warnings_map, warn_opts) do
    tags_enabled = Analyzer.matching_tags(warn_opts)

    for {_beam_file, warnings} <- warnings_map,
        {source_file, line, data} <- warnings,
        {tag, _, _} = data,
        tag in tags_enabled,
        source_file = Path.absname(to_string(source_file)),
        in_project?(source_file),
        not String.starts_with?(source_file, Mix.Project.deps_path()) do
      message = String.trim(to_string(:dialyzer.format_warning(data)))
      message = Regex.replace(Regex.recompile!(~r/^.*:\d+: /), message, "")

      %Mix.Task.Compiler.Diagnostic{
        compiler_name: "ElixirLS Dialyzer",
        file: source_file,
        position: line,
        message: message,
        severity: :warning,
        details: data
      }
    end
  end

  # Because mtime-based stale-checking has 1-second granularity, we err on the side of
  # re-analyzing files that were compiled during the same second as the last analysis
  defp adjusted_timestamp do
    seconds = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    :calendar.gregorian_seconds_to_datetime(seconds - 1)
  end
end
