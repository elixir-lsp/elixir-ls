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
    GenServer.cast(__MODULE__, {:parse_with_debounce, uri, source_file})
  end

  def parse_immediate(uri, source_file = %SourceFile{}) do
    GenServer.call(__MODULE__, {:parse_immediate, uri, source_file})
  end

  def parse_immediate(uri, source_file = %SourceFile{}, position) do
    GenServer.call(__MODULE__, {:parse_immediate, uri, source_file, position})
  end

  @impl true
  def init(_args) do
    # TODO get source files on start?
    {:ok, %{files: %{}, debounce_refs: %{}}}
  end

  # TODO terminate

  @impl true
  def handle_cast({:closed, uri}, state = %{files: files, debounce_refs: debounce_refs}) do
    {maybe_ref, updated_debounce_refs} = Map.pop(debounce_refs, uri)

    if maybe_ref do
      Process.cancel_timer(maybe_ref, info: false)
    end

    updated_files = Map.delete(files, uri)
    notify_diagnostics_updated(updated_files)
    {:noreply, %{state | files: updated_files, debounce_refs: updated_debounce_refs}}
  end

  def handle_cast({:parse_with_debounce, uri, source_file = %SourceFile{}}, state) do
    state =
      if should_parse?(uri, source_file) do
        state =
          update_in(state.debounce_refs[uri], fn old_ref ->
            if old_ref do
              Process.cancel_timer(old_ref, info: false)
            end

            Process.send_after(self(), {:parse_file, uri}, @debounce_timeout)
          end)

        update_in(state.files[uri], fn
          nil ->
            %Context{
              source_file: source_file,
              path: get_path(uri)
            }

          old_file ->
            %Context{old_file | source_file: source_file}
        end)
      else
        Logger.debug("Not parsing #{uri} with debounce: languageId #{source_file.language_id}")
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:parse_immediate, uri, source_file = %SourceFile{}},
        _from,
        %{files: files, debounce_refs: debounce_refs} = state
      ) do
    {reply, state} =
      if should_parse?(uri, source_file) do
        {maybe_ref, updated_debounce_refs} = Map.pop(debounce_refs, uri)

        if maybe_ref do
          Process.cancel_timer(maybe_ref, info: false)
        end

        current_version = source_file.version

        case files[uri] do
          %Context{parsed_version: ^current_version} = file ->
            Logger.debug("#{uri} already parsed")
            # current version already parsed
            {file, state}

          _other ->
            Logger.debug("Parsing #{uri} immediately: languageId #{source_file.language_id}")
            # overwrite everything
            file =
              %Context{
                source_file: source_file,
                path: get_path(uri)
              }
              |> do_parse()

            updated_files = Map.put(files, uri, file)

            notify_diagnostics_updated(updated_files)

            state = %{state | files: updated_files, debounce_refs: updated_debounce_refs}
            {file, state}
        end
      else
        Logger.debug("Not parsing #{uri} immediately: languageId #{source_file.language_id}")
        # not parsing - respond with empty struct
        reply = %Context{
          source_file: source_file,
          path: get_path(uri)
        }

        {reply, state}
      end

    {:reply, reply, state}
  end

  def handle_call(
        {:parse_immediate, uri, source_file = %SourceFile{}, position},
        _from,
        %{files: files, debounce_refs: debounce_refs} = state
      ) do
    {reply, state} =
      if should_parse?(uri, source_file) do
        {maybe_ref, updated_debounce_refs} = Map.pop(debounce_refs, uri)

        if maybe_ref do
          Process.cancel_timer(maybe_ref, info: false)
        end

        current_version = source_file.version

        case files[uri] do
          %Context{parsed_version: ^current_version} = file ->
            Logger.debug("#{uri} already parsed for cursor position #{inspect(position)}")
            file = maybe_fix_missing_env(file, position)

            updated_files = Map.put(files, uri, file)
            # no change to diagnostics, only update stored metadata
            state = %{state | files: updated_files, debounce_refs: updated_debounce_refs}
            {file, state}

          _other ->
            Logger.debug("Parsing #{uri} immediately: languageId #{source_file.language_id}")
            # overwrite everything
            file =
              %Context{
                source_file: source_file,
                path: get_path(uri)
              }
              |> do_parse(position)

            updated_files = Map.put(files, uri, file)

            notify_diagnostics_updated(updated_files)

            state = %{state | files: updated_files, debounce_refs: updated_debounce_refs}
            {file, state}
        end
      else
        Logger.debug("Not parsing #{uri} immediately: languageId #{source_file.language_id}")
        # not parsing - respond with empty struct
        reply = %Context{
          source_file: source_file,
          path: get_path(uri)
        }

        {reply, state}
      end

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info(
        {:parse_file, uri},
        %{files: files, debounce_refs: debounce_refs} = state
      ) do
    file = Map.fetch!(files, uri)
    Logger.debug("Parsing #{uri} after debounce: languageId #{file.source_file.language_id}")

    updated_file =
      file
      |> do_parse()

    updated_files = Map.put(files, uri, updated_file)

    state = %{state | files: updated_files, debounce_refs: Map.delete(debounce_refs, uri)}

    notify_diagnostics_updated(updated_files)

    {:noreply, state}
  end

  defp should_parse?(uri, source_file) do
    String.ends_with?(uri, [".ex", ".exs", ".eex"]) or
      source_file.language_id in ["elixir", "eex", "html-eex"]
  end

  @dummy_source ""
  @dummy_ast Code.string_to_quoted!(@dummy_source)
  @dummy_metadata ElixirSense.Core.Metadata.fill(@dummy_source, MetadataBuilder.build(@dummy_ast))

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
            message = Exception.format_banner(:error, e)

            diagnostic = %Mix.Task.Compiler.Diagnostic{
              compiler_name: "ElixirLS",
              file: file,
              position: {e.line, e.column},
              message: message,
              severity: :error,
              details: e
            }

            {:error, diagnostic}
        catch
          kind, err ->
            {payload, stacktrace} = Exception.blame(kind, err, __STACKTRACE__)

            message = Exception.format(kind, payload, stacktrace)

            diagnostic = %Mix.Task.Compiler.Diagnostic{
              compiler_name: "ElixirLS",
              file: file,
              # 0 means unknown
              position: 0,
              message: message,
              severity: :error,
              details: payload
            }

            # e.g. https://github.com/elixir-lang/elixir/issues/12926
            Logger.warning(
              "Unexpected parser error, please report it to elixir project https://github.com/elixir-lang/elixir/issues\n" <>
                message
            )

            JsonRpc.telemetry(
              "parser_error",
              %{"elixir_ls.parser_error" => message},
              %{}
            )

            {:error, diagnostic}
        end
      end)

    warning_diagnostics =
      raw_diagnostics
      |> Enum.map(fn raw ->
        Diagnostics.code_diagnostic(raw)
      end)

    case result do
      {:ok, ast} -> {ast, warning_diagnostics}
      {:error, diagnostic} -> {nil, [diagnostic | warning_diagnostics]}
    end
  end
end
