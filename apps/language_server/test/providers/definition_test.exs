defmodule ElixirLS.LanguageServer.Providers.DefinitionTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.Definition
  alias ElixirLS.LanguageServer.Protocol.Location
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder
  require ElixirLS.Test.TextLoc

  test "find definition remote function call" do
    file_path = FixtureHelpers.get_path("references_remote.ex")
    parser_context = ParserContextBuilder.from_path(file_path)

    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {4, 28}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        ReferencesReferenced.referenced_fun()
                                ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 1, "character" => 2},
             "end" => %{"line" => 6, "character" => 5}
           }
  end

  test "find definition remote macro call" do
    file_path = FixtureHelpers.get_path("references_remote.ex")
    parser_context = ParserContextBuilder.from_path(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {8, 28}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        ReferencesReferenced.referenced_macro a do
                                ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 8, "character" => 2},
             "end" => %{"line" => 12, "character" => 5}
           }
  end

  test "find definition imported function call" do
    file_path = FixtureHelpers.get_path("references_imported.ex")
    parser_context = ParserContextBuilder.from_path(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {4, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_fun()
         ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 1, "character" => 2},
             "end" => %{"line" => 6, "character" => 5}
           }
  end

  test "find definition imported macro call" do
    file_path = FixtureHelpers.get_path("references_imported.ex")
    parser_context = ParserContextBuilder.from_path(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {8, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_macro a do
         ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 8, "character" => 2},
             "end" => %{"line" => 12, "character" => 5}
           }
  end

  test "find definition local function call" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    parser_context = ParserContextBuilder.from_path(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {15, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_fun()
         ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 1, "character" => 2},
             "end" => %{"line" => 6, "character" => 5}
           }
  end

  test "find definition local macro call" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    parser_context = ParserContextBuilder.from_path(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {19, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        referenced_macro a do
         ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 8, "character" => 2},
             "end" => %{"line" => 12, "character" => 5}
           }
  end

  test "find definition variable" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    parser_context = ParserContextBuilder.from_path(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {4, 13}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        IO.puts(referenced_variable + 1)
                 ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 2, "character" => 4},
             "end" => %{"line" => 2, "character" => 23}
           }
  end

  test "find definition attribute" do
    file_path = FixtureHelpers.get_path("references_referenced.ex")
    parser_context = ParserContextBuilder.from_path(file_path)
    uri = SourceFile.Path.to_uri(file_path)

    b_file_path = FixtureHelpers.get_path("references_referenced.ex")
    b_uri = SourceFile.Path.to_uri(b_file_path)

    {line, char} = {27, 5}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        @referenced_attribute
         ^
    """)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, %Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == %{
             "start" => %{"line" => 24, "character" => 2},
             "end" => %{"line" => 24, "character" => 23}
           }
  end
end
