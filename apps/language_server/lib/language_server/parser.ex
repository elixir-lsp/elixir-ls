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
  require Logger

  @debounce_timeout 300

  defstruct [
    :source_file,
    :path,
    :ast,
    :diagnostics
  ]

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def notify_closed(uri) do
    GenServer.cast(__MODULE__, {:closed, uri})
  end

  def parse_with_debounce(uri, source_file) do
    GenServer.cast(__MODULE__, {:parse_with_debounce, uri, source_file})
  end

  @impl true
  def init(_args) do
    # TODO get source files on start?
    {:ok, %{files: %{}, debounce_refs: %{}}}
  end

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
    state = if String.ends_with?(uri, [".ex", ".exs", ".eex"]) do
      state = update_in(state.debounce_refs[uri], fn old_ref ->
        if old_ref do
          Process.cancel_timer(old_ref, info: false)
        end

        Process.send_after(self(), {:parse_file, uri}, @debounce_timeout)
      end)

      update_in(state.files[uri], fn _old_file ->
        %__MODULE__{
          source_file: source_file,
          path: get_path(uri),
          ast: nil,
          diagnostics: []
        }
      end)
    else
      state
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:parse_file, uri},
        %{files: files, debounce_refs: debounce_refs} = state
      ) do
    Logger.debug("Parsing #{uri}")
    %__MODULE__{source_file: source_file, path: path} = file = Map.fetch!(files, uri)
    {ast, diagnostics} = parse_file(source_file.text, path)
    updated_file = %__MODULE__{file |
      ast: ast,
      diagnostics: diagnostics
    }

    updated_files = Map.put(files, uri, updated_file)

    state = %{state | files: updated_files, debounce_refs: Map.delete(debounce_refs, uri)}

    notify_diagnostics_updated(updated_files)

    {:noreply, state}
  end

  defp get_path(uri) do
    case uri do
      "file:" <> _ -> SourceFile.Path.from_uri(uri)
      _ ->
        extension = uri
        |> String.split(".")
        |> List.last
        "nofile." <> extension
    end
  end

  defp notify_diagnostics_updated(updated_files) do
    updated_files
    |> Enum.map(fn {_uri, %__MODULE__{diagnostics: diagnostics}} -> diagnostics end)
    |> List.flatten
    |> Server.parser_finished()
  end


  # TODO uri instead of file?
  # defp parse_file(_text, nil), do: {nil, []}
  defp parse_file(text, file) do
    {result, raw_diagnostics} =
      Build.with_diagnostics([log: false], fn ->
        try do
          parser_options = [
            file: file,
            columns: true
          ]

          ast = if String.ends_with?(file, ".eex") do
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
            message = Exception.message(e)

            diagnostic = %Mix.Task.Compiler.Diagnostic{
              compiler_name: "ElixirLS",
              file: file,
              position: {e.line, e.column},
              message: message,
              severity: :error
            }

            {:error, diagnostic}

          e ->
            message = Exception.message(e)

            diagnostic = %Mix.Task.Compiler.Diagnostic{
              compiler_name: "ElixirLS",
              file: file,
              position: {1, 1},
              message: message,
              severity: :error
            }

            # e.g. https://github.com/elixir-lang/elixir/issues/12926
            Logger.warning(
              "Unexpected parser error, please report it to elixir project https://github.com/elixir-lang/elixir/issues\n" <>
                Exception.format(:error, e, __STACKTRACE__)
            )

            JsonRpc.telemetry(
              "parser_error",
              %{"elixir_ls.parser_error" => Exception.format(:error, e, __STACKTRACE__)},
              %{}
            )

            {:error, diagnostic}
        end
      end)

    warning_diagnostics =
      raw_diagnostics
      |> Enum.map(&Diagnostics.code_diagnostic/1)

    case result do
      {:ok, ast} -> {ast, warning_diagnostics}
      {:error, diagnostic} -> {nil, [diagnostic | warning_diagnostics]}
    end
  end
end
