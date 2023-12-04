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
      :parsed_version
    ]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def notify_closed(uri) do
    GenServer.cast(__MODULE__, {:closed, uri})
  end

  def parse_with_debounce(uri, source_file) do
    GenServer.cast(__MODULE__, {:parse_with_debounce, uri, source_file})
  end

  def parse_immediate(uri, source_file) do
    GenServer.call(__MODULE__, {:parse_immediate, uri, source_file})
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

  def handle_cast({:parse_with_debounce, uri, source_file}, state) do
    state = if should_parse?(uri, source_file) do
      state = update_in(state.debounce_refs[uri], fn old_ref ->
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
          %Context{old_file |
            source_file: source_file
          }
      end)
    else
      Logger.debug("Not parsing #{uri} with debounce: languageId #{source_file.language_id}")
      state
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:parse_immediate, uri, source_file}, _from, %{files: files, debounce_refs: debounce_refs} = state) do
    {reply, state} = if should_parse?(uri, source_file) do
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
          file = %Context{
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

  @impl GenServer
  def handle_info(
        {:parse_file, uri},
        %{files: files, debounce_refs: debounce_refs} = state
      ) do
    file = Map.fetch!(files, uri)
    Logger.debug("Parsing #{uri} after debounce: languageId #{file.source_file.language_id}")

    updated_file = file
    |> do_parse()

    updated_files = Map.put(files, uri, updated_file)

    state = %{state | files: updated_files, debounce_refs: Map.delete(debounce_refs, uri)}

    notify_diagnostics_updated(updated_files)

    {:noreply, state}
  end

  defp should_parse?(uri, source_file) do
    String.ends_with?(uri, [".ex", ".exs", ".eex"]) or source_file.language_id in ["elixir", "eex", "html-eex"]
  end

  defp do_parse(%Context{source_file: source_file, path: path} = file) do
    {ast, diagnostics} = parse_file(source_file.text, path, source_file.language_id)

    metadata = if ast do
      acc = MetadataBuilder.build(ast)
      ElixirSense.Core.Metadata.fill(source_file.text, acc)
    end

    %Context{file |
      ast: ast,
      diagnostics: diagnostics,
      metadata: metadata,
      parsed_version: source_file.version
    }
  end

  defp get_path(uri) do
    case uri do
      "file:" <> _ -> SourceFile.Path.from_uri(uri)
      _ ->
        "nofile"
    end
  end

  defp notify_diagnostics_updated(updated_files) do
    updated_files
    |> Map.new(fn {uri, %Context{diagnostics: diagnostics, parsed_version: version}} -> {uri, {version, diagnostics}} end)
    |> Server.parser_finished()
  end

  defp parse_file(text, file, language_id) do
    {result, raw_diagnostics} =
      Build.with_diagnostics([log: false], fn ->
        try do
          parser_options = [
            file: file,
            columns: true
          ]

          ast = if is_binary(file) and String.ends_with?(file, ".eex") or language_id in ["eex", "html-eex"] do
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
