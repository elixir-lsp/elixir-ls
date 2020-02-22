defmodule ElixirLS.LanguageServer.Providers.DefinitionTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.Definition
  alias ElixirLS.LanguageServer.Protocol.Location
  require ElixirLS.Test.TextLoc

  test "find definition" do
    file_path = Path.join(__DIR__, "../../support/references_a.ex") |> Path.expand()
    text = File.read!(file_path)
    uri = "file://#{file_path}"

    b_file_path = Path.join(__DIR__, "../../support/references_b.ex") |> Path.expand()
    b_uri = "file://#{b_file_path}"

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
