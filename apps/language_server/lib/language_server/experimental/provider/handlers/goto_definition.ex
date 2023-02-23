defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.GotoDefinition do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.GotoDefinition
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  require Logger

  def handle(%GotoDefinition{} = request, _) do
    source_file = request.source_file
    pos = request.position

    maybe_location =
      source_file |> SourceFile.to_string() |> ElixirSense.definition(pos.line, pos.character + 1)

    case to_response(request.id, maybe_location, source_file) do
      {:ok, response} ->
        {:reply, response}

      {:error, reason} ->
        Logger.error("GotoDefinition conversion failed: #{inspect(reason)}")
        {:error, Responses.GotoDefinition.error(request.id, :request_failed, inspect(reason))}
    end
  end

  defp to_response(request_id, %ElixirSense.Location{} = location, %SourceFile{} = source_file) do
    with {:ok, lsp_location} <- Conversions.to_lsp(location, source_file) do
      {:ok, Responses.GotoDefinition.new(request_id, lsp_location)}
    end
  end

  defp to_response(request_id, nil, _source_file) do
    {:ok, Responses.GotoDefinition.new(request_id, nil)}
  end
end
