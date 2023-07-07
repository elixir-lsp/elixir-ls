defmodule ElixirLS.LanguageServer.Providers.DefinitionTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.Definition
  alias ElixirLS.LanguageServer.Protocol.Location
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  require ElixirLS.Test.TextLoc

  test "find definition remote function call" do
    file_path = FixtureHelpers.get_path("references_remote.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {4, 28}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        ReferencesReferenced.referenced_fun()
                                ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 1, "character" => 2},
             "end" => %{"line" => 1, "character" => 2}
           }
  end

  test "find definition remote macro call" do
    file_path = FixtureHelpers.get_path("references_remote.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {8, 28}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        ReferencesReferenced.referenced_macro a do
                                ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 8, "character" => 2},
             "end" => %{"line" => 8, "character" => 2}
           }
  end

  test "find definition imported function call" do
    file_path = FixtureHelpers.get_path("references_imported.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {4, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_fun()
         ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 1, "character" => 2},
             "end" => %{"line" => 1, "character" => 2}
           }
  end

  test "find definition imported macro call" do
    file_path = FixtureHelpers.get_path("references_imported.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {8, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_macro a do
         ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 8, "character" => 2},
             "end" => %{"line" => 8, "character" => 2}
           }
  end

  test "find definition local function call" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {15, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_fun()
         ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 1, "character" => 2},
             "end" => %{"line" => 1, "character" => 2}
           }
  end

  test "find definition local macro call" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {19, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_macro a do
         ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 8, "character" => 2},
             "end" => %{"line" => 8, "character" => 2}
           }
  end

  test "find definition variable" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {4, 13}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        IO.puts(referenced_variable + 1)
                 ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 2, "character" => 4},
             "end" => %{"line" => 2, "character" => 4}
           }
  end

  test "find definition attribute" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    text = File.read!(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {27, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        @referenced_attribute
         ^
    """)

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, text, line, char)

    assert range == %{
             "start" => %{"line" => 24, "character" => 2},
             "end" => %{"line" => 24, "character" => 2}
           }
  end
end
