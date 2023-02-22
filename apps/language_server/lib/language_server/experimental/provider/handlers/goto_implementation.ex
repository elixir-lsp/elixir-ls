defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.GotoImplementation do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.GotoImplementation
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  require Logger

  def handle(%GotoImplementation{} = request, _) do
    source_file = request.source_file
    pos = request.position

    locations =
      source_file
      |> SourceFile.to_string()
      |> ElixirSense.implementations(pos.line, pos.character + 1)

    results =
      locations
      |> Enum.map(&Conversions.to_lsp(&1, source_file))
      |> then(&for({:ok, result} <- &1, do: result))

    {:reply, Responses.GotoImplementation.new(request.id, results)}
  end
end
