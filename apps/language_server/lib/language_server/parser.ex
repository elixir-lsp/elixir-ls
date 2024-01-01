defmodule ElixirLS.LanguageServer.Parser do
  @moduledoc """
  This server parses source files and maintains cache of AST and metadata
  """
  use GenServer
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Diagnostics
  alias ElixirLS.LanguageServer.Build
  alias ElixirLS.LanguageServer.Server
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Core.MetadataBuilder
  require Logger

  @debounce_timeout 300
  @parse_timeout 120_000

  @dummy_source ""
  @dummy_ast Code.string_to_quoted!(@dummy_source)
  @dummy_metadata ElixirSense.Core.Metadata.fill(@dummy_source, MetadataBuilder.build(@dummy_ast))

  defmodule Context do
    defstruct [
      :source_file,
      :path,
      :ast,
      :diagnostics,
      :metadata,
      :parsed_version,
      :flag
    ]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def notify_closed(uri) do
    GenServer.cast(__MODULE__, {:closed, uri})
  end

  def parse_with_debounce(uri, source_file = %SourceFile{}) do
    if should_parse?(uri, source_file) do
      GenServer.cast(__MODULE__, {:parse_with_debounce, uri, source_file})
    else
      Logger.debug(
        "Not parsing #{uri} version #{source_file.version} languageId #{source_file.language_id} with debounce"
      )

      :ok
    end
  end

  def parse_immediate(uri, source_file = %SourceFile{}, position \\ nil) do
    if should_parse?(uri, source_file) do
      case GenServer.call(
             __MODULE__,
             {:parse_immediate, uri, source_file, position},
             @parse_timeout
           ) do
        :error -> raise "parser error"
        :stale -> raise Server.ContentModifiedError, uri
        %Context{} = context -> context
      end
    else
      Logger.debug(
        "Not parsing #{uri} version #{source_file.version} languageId #{source_file.language_id} immediately"
      )

      # not parsing - respond with empty struct
      %Context{
        source_file: source_file,
        path: get_path(uri),
        ast: @dummy_ast,
        metadata: @dummy_metadata
      }
    end
  end

  @impl true
  def init(_args) do
    # TODO get source files on start?
    {:ok, %{files: %{}, debounce_refs: %{}, parse_pids: %{}, parse_uris: %{}, queue: []}}
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
    end

    :ok
  end

  @impl true
  def handle_cast({:closed, uri}, state = %{files: files}) do
    state = cancel_debounce(state, uri)

    # TODO maybe cancel parse

    updated_files = Map.delete(files, uri)
    notify_diagnostics_updated(updated_files)
    {:noreply, %{state | files: updated_files}}
  end

  def handle_cast(
        {:parse_with_debounce, uri, source_file = %SourceFile{version: current_version}},
        state
      ) do
    state =
      update_in(state.debounce_refs[uri], fn
        nil ->
          {Process.send_after(self(), {:parse_file, uri}, @debounce_timeout), current_version}

        {old_ref, ^current_version} ->
          {old_ref, current_version}

        {old_ref, old_version} when old_version < current_version ->
          Process.cancel_timer(old_ref, info: false)
          {Process.send_after(self(), {:parse_file, uri}, @debounce_timeout), current_version}
      end)

    state =
      update_in(state.files[uri], fn
        nil ->
          %Context{
            source_file: source_file,
            path: get_path(uri)
          }

        %Context{source_file: %SourceFile{version: old_version}} = old_file
        when current_version > old_version ->
          %Context{old_file | source_file: source_file}

        %Context{} = old_file ->
          old_file
      end)

    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:parse_immediate, uri, source_file = %SourceFile{}, position},
        from,
        %{files: files} = state
      ) do
    current_version = source_file.version
    parent = self()

    case {files[uri], Map.has_key?(state.parse_pids, {uri, current_version})} do
      {%Context{parsed_version: ^current_version} = file, _} ->
        Logger.debug(
          "#{uri} version #{current_version} languageId #{source_file.language_id} already parsed"
        )

        file = maybe_fix_missing_env(file, position)

        {:reply, file, state}

      {_, true} ->
        Logger.debug(
          "#{uri} version #{current_version} languageId #{source_file.language_id} is currently being parsed"
        )

        state = %{state | queue: state.queue ++ [{{uri, current_version, position}, from}]}
        {:noreply, state}

      {%Context{source_file: %SourceFile{version: old_version}}, _}
      when old_version > current_version ->
        {:reply, :stale, state}

      {other, _} ->
        state = cancel_debounce(state, uri)

        updated_file =
          case other do
            nil ->
              Logger.debug(
                "Parsing #{uri} version #{current_version} languageId #{source_file.language_id} immediately"
              )

              %Context{
                source_file: source_file,
                path: get_path(uri)
              }

            %Context{source_file: %SourceFile{version: old_version}} = old_file
            when old_version <= current_version ->
              Logger.debug(
                "Parsing #{uri} version #{current_version} languageId #{source_file.language_id} immediately"
              )

              %Context{old_file | source_file: source_file}
          end

        {pid, ref} =
          spawn_monitor(fn ->
            updated_file = do_parse(updated_file, position)
            send(parent, {:parse_file_done, uri, updated_file, from})
          end)

        {:noreply,
         %{
           state
           | files: Map.put(files, uri, updated_file),
             parse_pids: Map.put(state.parse_pids, {uri, current_version}, {pid, ref, from}),
             parse_uris: Map.put(state.parse_uris, ref, {uri, current_version})
         }}
    end
  end

  @impl GenServer
  def handle_info(
        {:parse_file, uri},
        %{files: files, debounce_refs: debounce_refs} = state
      ) do
    file = Map.fetch!(files, uri)
    version = file.source_file.version

    Logger.debug(
      "Parsing #{uri} version #{version} languageId #{file.source_file.language_id} after debounce"
    )

    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        updated_file = do_parse(file)
        send(parent, {:parse_file_done, uri, updated_file, nil})
      end)

    state = %{
      state
      | debounce_refs: Map.delete(debounce_refs, uri),
        parse_pids: Map.put(state.parse_pids, {uri, version}, {pid, ref, nil}),
        parse_uris: Map.put(state.parse_uris, ref, {uri, version})
    }

    {:noreply, state}
  end

  def handle_info(
        {:parse_file_done, uri, updated_file, from},
        %{files: files} = state
      ) do
    if from do
      GenServer.reply(from, updated_file)
    end

    parsed_file_version = updated_file.parsed_version

    state =
      case files[uri] do
        nil ->
          # file got closed, no need to do anything
          state

        %Context{source_file: %SourceFile{version: version}} when version > parsed_file_version ->
          # result is from stale request, discard it
          state

        _ ->
          updated_files = Map.put(files, uri, updated_file)
          notify_diagnostics_updated(updated_files)
          %{state | files: updated_files}
      end

    queue =
      Enum.reduce(state.queue, [], fn
        {{^uri, ^parsed_file_version, position}, from}, acc ->
          file = maybe_fix_missing_env(updated_file, position)
          GenServer.reply(from, file)
          acc

        {request, from}, acc ->
          [{request, from} | acc]
      end)
      |> Enum.reverse()

    {:noreply, %{state | queue: queue}}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %{parse_pids: parse_pids, parse_uris: parse_uris} = state
      ) do
    {{uri, version}, updated_parse_uris} = Map.pop!(parse_uris, ref)
    {{^pid, ^ref, from}, updated_parse_pids} = Map.pop!(parse_pids, {uri, version})

    if reason != :normal and from != nil do
      GenServer.reply(from, :error)
    end

    state = %{state | parse_pids: updated_parse_pids, parse_uris: updated_parse_uris}

    {:noreply, state}
  end

  defp should_parse?(uri, source_file) do
    String.ends_with?(uri, [".ex", ".exs", ".eex"]) or
      source_file.language_id in ["elixir", "eex", "html-eex"]
  end

  defp maybe_fix_missing_env(%Context{} = file, nil), do: file

  defp maybe_fix_missing_env(
         %Context{metadata: metadata, flag: flag, source_file: source_file = %SourceFile{}} =
           file,
         {line, _character} = cursor_position
       ) do
    if Map.has_key?(metadata.lines_to_env, line) do
      file
    else
      case flag do
        {_, ^cursor_position} ->
          # give up - we already tried
          file

        {:exact, _} ->
          # file does not have parse errors, try to parse again with marker
          metadata =
            case ElixirSense.Core.Parser.try_fix_line_not_found_by_inserting_marker(
                   source_file.text,
                   cursor_position
                 ) do
              {:ok, acc} ->
                Logger.debug("Fixed missing env")
                ElixirSense.Core.Metadata.fill(source_file.text, acc)

              _ ->
                Logger.debug("Not able to fix missing env")
                metadata
            end

          %Context{file | metadata: metadata, flag: {:exact, cursor_position}}

        :not_parsable ->
          # give up - no support in fault tolerant parser
          file

        {f, _cursor_position} when f in [:not_parsable, :fixed] ->
          # reparse with cursor position
          {flag, ast, metadata} = fault_tolerant_parse(source_file, cursor_position)
          %Context{file | ast: ast, metadata: metadata, flag: flag}
      end
    end
  end

  def do_parse(
        %Context{source_file: source_file = %SourceFile{}, path: path} = file,
        cursor_position \\ nil
      ) do
    {ast, diagnostics} = parse_file(source_file.text, path, source_file.language_id)

    {flag, ast, metadata} =
      if ast do
        # no syntax errors
        metadata =
          MetadataBuilder.build(ast)
          |> fix_missing_env(source_file.text, cursor_position)

        {{:exact, cursor_position}, ast, metadata}
      else
        if elixir?(path, source_file.language_id) do
          fault_tolerant_parse(source_file, cursor_position)
        else
          # no support for eex in ElixirSense.Core.Parser
          {:not_parsable, @dummy_ast, @dummy_metadata}
        end
      end

    %Context{
      file
      | ast: ast,
        diagnostics: diagnostics,
        metadata: metadata,
        parsed_version: source_file.version,
        flag: flag
    }
  end

  defp fault_tolerant_parse(source_file = %SourceFile{}, cursor_position) do
    # attempt to parse with fixing syntax errors
    options = [
      errors_threshold: 3,
      cursor_position: cursor_position,
      fallback_to_container_cursor_to_quoted: true
    ]

    case ElixirSense.Core.Parser.string_to_ast(source_file.text, options) do
      {:ok, ast, modified_source, _error} ->
        Logger.debug("Syntax error fixed")

        metadata =
          MetadataBuilder.build(ast)
          |> fix_missing_env(modified_source, cursor_position)

        {{:fixed, cursor_position}, ast, metadata}

      _ ->
        Logger.debug("Not able to fix syntax error")
        # we can't fix it
        {{:not_parsable, cursor_position}, @dummy_ast, @dummy_metadata}
    end
  catch
    kind, err ->
      {payload, stacktrace} = Exception.blame(kind, err, __STACKTRACE__)

      message = Exception.format(kind, payload, stacktrace)

      Logger.warning(
        "Unexpected parser error, please report it to elixir project https://github.com/elixir-lang/elixir/issues\n" <>
          message
      )

      JsonRpc.telemetry(
        "parser_error",
        %{"elixir_ls.parser_error" => message},
        %{}
      )

      {{:not_parsable, cursor_position}, @dummy_ast, @dummy_metadata}
  end

  defp fix_missing_env(acc, source, nil), do: ElixirSense.Core.Metadata.fill(source, acc)

  defp fix_missing_env(acc, source, {line, _} = cursor_position) do
    acc =
      if Map.has_key?(acc.lines_to_env, line) do
        acc
      else
        case ElixirSense.Core.Parser.try_fix_line_not_found_by_inserting_marker(
               source,
               cursor_position
             ) do
          {:ok, acc} ->
            Logger.debug("Fixed missing env")
            acc

          _ ->
            Logger.debug("Not able to fix missing env")
            acc
        end
      end

    ElixirSense.Core.Metadata.fill(source, acc)
  end

  defp get_path(uri) do
    case uri do
      "file:" <> _ ->
        SourceFile.Path.from_uri(uri)

      _ ->
        "nofile"
    end
  end

  defp cancel_debounce(state = %{debounce_refs: debounce_refs}, uri) do
    {maybe_ref, updated_debounce_refs} = Map.pop(debounce_refs, uri)

    if maybe_ref do
      {ref, _version} = maybe_ref
      Process.cancel_timer(ref, info: false)
    end

    %{state | debounce_refs: updated_debounce_refs}
  end

  defp notify_diagnostics_updated(updated_files) do
    updated_files
    |> Map.new(fn {uri, %Context{diagnostics: diagnostics, parsed_version: version}} ->
      {uri, {version, diagnostics}}
    end)
    |> Server.parser_finished()
  end

  defp elixir?(file, language_id) do
    (is_binary(file) and (String.ends_with?(file, ".ex") or String.ends_with?(file, ".exs"))) or
      language_id in ["elixir"]
  end

  defp eex?(file, language_id) do
    (is_binary(file) and String.ends_with?(file, ".eex")) or language_id in ["eex", "html-eex"]
  end

  defp parse_file(text, file, language_id) do
    {result, raw_diagnostics} =
      Build.with_diagnostics([log: false], fn ->
        try do
          parser_options = [
            file: file,
            columns: true,
            token_metadata: true
          ]

          ast =
            if eex?(file, language_id) do
              EEx.compile_string(text,
                file: file,
                parser_options: parser_options
              )
            else
              Code.string_to_quoted!(text, parser_options)
            end

          {:ok, ast}
        rescue
          e in [EEx.SyntaxError, SyntaxError, TokenMissingError, MismatchedDelimiterError] ->
            diagnostic = Diagnostics.from_error(:error, e, __STACKTRACE__, file, :no_stacktrace)

            {:error, diagnostic}
        catch
          kind, err ->
            diagnostic = Diagnostics.from_error(kind, err, __STACKTRACE__, file, :no_stacktrace)

            # e.g. https://github.com/elixir-lang/elixir/issues/12926
            Logger.warning(
              "Unexpected parser error, please report it to elixir project https://github.com/elixir-lang/elixir/issues\n" <>
                diagnostic.message
            )

            JsonRpc.telemetry(
              "parser_error",
              %{"elixir_ls.parser_error" => diagnostic.message},
              %{}
            )

            {:error, diagnostic}
        end
      end)

    warning_diagnostics =
      raw_diagnostics
      |> Enum.map(fn raw ->
        Diagnostics.from_code_diagnostic(raw, file, :no_stacktrace)
      end)

    case result do
      {:ok, ast} -> {ast, warning_diagnostics}
      {:error, diagnostic} -> {nil, [diagnostic | warning_diagnostics]}
    end
  end
end
