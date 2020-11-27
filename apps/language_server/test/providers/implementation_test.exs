defmodule ElixirLS.LanguageServer.Providers.ImplementationTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.Implementation
  alias ElixirLS.LanguageServer.Protocol.Location
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  require ElixirLS.Test.TextLoc

  test "find implementations" do
    # force load as currently only loaded or loadable modules that are a part
    # of an application are found
    Code.ensure_loaded?(ElixirLS.LanguageServer.Fixtures.ExampleBehaviourImpl)

    file_path = FixtureHelpers.get_path("example_behaviour.ex")
    text = File.read!(file_path)
    uri = SourceFile.path_to_uri(file_path)

    {line, char} = {0, 43}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
    defmodule ElixirLS.LanguageServer.Fixtures.ExampleBehaviour do
                                               ^
    """)

    assert {:ok, [%Location{uri: ^uri, range: range}]} =
             Implementation.implementation(uri, text, line, char)

    assert range ==
             %{
               "start" => %{"line" => 5, "character" => 10},
               "end" => %{"line" => 5, "character" => 10}
             }
  end
end
