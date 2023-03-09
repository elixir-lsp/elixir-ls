defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.GotoImplementation do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.GotoImplementation
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  require Logger

  def handle(%GotoImplementation{} = request, _) do
    source_file = request.source_file
    pos = request.position

    elixir_sense_locations =
      source_file
      |> SourceFile.to_string()
      |> ElixirSense.implementations(pos.line, pos.character + 1)

    locations =
      for {:ok, location} <-
            Enum.map(elixir_sense_locations, &Conversions.to_lsp(&1, source_file)) do
        location
      end

    {:reply, Responses.GotoImplementation.new(request.id, locations)}
  end
end
