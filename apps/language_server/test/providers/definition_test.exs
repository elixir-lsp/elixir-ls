defmodule ElixirLS.LanguageServer.Providers.DefinitionTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.Definition
  alias ElixirLS.LanguageServer.Protocol.Location
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  require ElixirLS.Test.TextLoc

  test "find definition" do
    file_path = FixtureHelpers.get_path("references_a.ex")
    text = File.read!(file_path)
    uri = SourceFile.path_to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_b.ex")
    b_uri = SourceFile.path_to_uri(b_file_path)

    {line, char} = {2, 30}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        ElixirLS.Test.ReferencesB.b_fun()
                                  ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 1, "character" => 6},
             "end" => %{"line" => 1, "character" => 6}
           }
  end
end
