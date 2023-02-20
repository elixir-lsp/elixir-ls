defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.GotoDefinition do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.GotoDefinition
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Location, as: CodeModLocation
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  require Logger

  def handle(%GotoDefinition{} = request, _) do
    source_file = request.source_file
    pos = request.position

    source_file_string = source_file |> SourceFile.to_string()

    with %ElixirSense.Location{} = location <-
           ElixirSense.definition(source_file_string, pos.line, pos.character + 1),
         {:ok, definition} <- CodeModLocation.to_lsp(location, source_file) do
      {:reply, Responses.GotoDefinition.new(request.id, definition)}
    else
      nil ->
        {:reply, Responses.GotoDefinition.new(request.id, nil)}

      {:error, reason} ->
        Logger.error("GotoDefinition failed: #{inspect(reason)}")
        {:error, Responses.GotoDefinition.error(request.id, :request_failed, reason)}
    end
  end
end
