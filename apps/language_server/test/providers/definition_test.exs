defmodule ElixirLS.LanguageServer.Providers.DefinitionTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.Definition
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder
  require ElixirLS.Test.TextLoc
  import ElixirLS.LanguageServer.RangeUtils

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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(1, 2, 6, 5)
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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(8, 2, 12, 5)
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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(1, 2, 6, 5)
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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(8, 2, 12, 5)
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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(1, 2, 6, 5)
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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(8, 2, 12, 5)
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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(2, 4, 2, 23)
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

    assert {:ok, %GenLSP.Structures.Location{uri: ^b_uri, range: range}} =
             Definition.definition(uri, parser_context, line, char, File.cwd!())

    assert range == range(24, 2, 24, 23)
  end
end
