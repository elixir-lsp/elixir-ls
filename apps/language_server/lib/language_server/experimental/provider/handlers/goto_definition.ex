defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.GotoDefinition do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.GotoDefinition
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Location
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range, as: LSRange
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  require Logger

  def handle(%GotoDefinition{} = request, _) do
    source_file = request.source_file
    pos = request.position

    source_file_string = source_file |> SourceFile.to_string()

    with %ElixirSense.Location{} = location <-
           ElixirSense.definition(source_file_string, pos.line, pos.character + 1),
         {:ok, definition} <- build_definition(location, source_file) do
      {:reply, Responses.GotoDefinition.new(request.id, definition)}
    else
      nil ->
        {:reply, Responses.GotoDefinition.new(request.id, nil)}

      {:error, reason} ->
        Logger.error("GotoDefinition failed: #{inspect(reason)}")
        {:error, Responses.GotoDefinition.error(request.id, :request_failed, reason)}
    end
  end

  defp build_definition(
         %{line: line, column: column} = elixir_sense_definition,
         current_source_file
       ) do
    position = SourceFile.Position.new(line, column - 1)

    with {:ok, source_file} <- get_source_file(elixir_sense_definition, current_source_file),
         {:ok, ls_position} <- Conversions.to_lsp(position, source_file) do
      ls_range = %LSRange{start: ls_position, end: ls_position}
      {:ok, Location.new(uri: source_file.uri, range: ls_range)}
    end
  end

  defp get_source_file(%{file: nil}, current_source_file) do
    {:ok, current_source_file}
  end

  defp get_source_file(%{file: path}, _) do
    uri = Conversions.ensure_uri(path)
    SourceFile.Store.open_temporary(uri)
  end
end
