defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.GotoImplementationTest do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.GotoImplementation
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types, as: LSPTypes
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Provider.Handlers
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions

  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.Test.FixtureHelpers

  import LspProtocol
  import ElixirLS.Test.TextLoc, only: [annotate_assert: 4]

  use ExUnit.Case, async: false

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  def request(file_path, line, char) do
    uri = Conversions.ensure_uri(file_path)

    params = [
      text_document: [uri: uri],
      position: [line: line, character: char]
    ]

    with {:ok, contents} <- File.read(file_path),
         :ok <- SourceFile.Store.open(uri, contents, 1),
         {:ok, req} <- build(GotoImplementation, params) do
      GotoImplementation.to_elixir(req)
    end
  end

  def handle(request) do
    Handlers.GotoImplementation.handle(request, Env.new())
  end

  test "find implementations" do
    Code.ensure_loaded?(ElixirLS.LanguageServer.Fixtures.ExampleBehaviourImpl)
    file_path = FixtureHelpers.get_path("example_behaviour.ex")
    {line, char} = {0, 43}

    {:ok, request} = request(file_path, line, char)

    annotate_assert(file_path, line, char, """
    defmodule ElixirLS.LanguageServer.Fixtures.ExampleBehaviour do
                                               ^
    """)

    {:reply, response} = handle(request)

    assert %{result: [location]} = response
    assert String.ends_with?(location.uri, "example_behaviour.ex")

    assert location.range == %LSPTypes.Range{
             end: %LSPTypes.Position{character: 10, line: 5},
             start: %LSPTypes.Position{character: 10, line: 5}
           }
  end
end
