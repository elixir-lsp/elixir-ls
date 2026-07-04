defmodule ElixirLS.LanguageServer.Providers.HoverTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  import ElixirLS.LanguageServer.Test.PlatformTestHelpers
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder

  alias ElixirLS.LanguageServer.Providers.Hover

  def fake_dir() do
    Path.join(__DIR__, "../../../..") |> Path.expand() |> maybe_convert_path_separators()
  end

  test "blank hover" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    {line, char} = {2, 1}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok, resp} = Hover.hover(parser_context, line, char)
    assert nil == resp
  end

  test "elixir module hover" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    {line, char} = {2, 5}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\nIO\n```\n\n*module* [View on hexdocs](https://hexdocs.pm/elixir/#{System.version()}/IO.html)"
           )
  end

  # elixir-lsp/elixir-ls#1027: at the end of the alias `IO` (on the `.` before `inspect`) the module
  # is hovered, not the remote function - the same trailing-edge resolution the definition locator uses.
  test "elixir module hover at the end of an alias before `.` (#1027)" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    # `IO` is on line 3, columns 5-6; the caret sits just past it, on the `.` (0-based char 6).
    {line, char} = {2, 6}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} = Hover.hover(parser_context, line, char)

    assert String.starts_with?(v, "```elixir\nIO\n```\n\n*module*")
  end

  test "function hover" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    {line, char} = {2, 10}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\nIO.inspect(item, opts \\\\ [])\n```\n\n*function* [View on hexdocs](https://hexdocs.pm/elixir/#{System.version()}/IO.html#inspect/2)"
           )
  end

  test "macro hover" do
    text = """
    defmodule MyModule do
      import Abc
    end
    """

    {line, char} = {1, 3}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\nKernel.SpecialForms.import(module, opts)\n```\n\n*macro* [View on hexdocs](https://hexdocs.pm/elixir/#{System.version()}/Kernel.SpecialForms.html#import/2)"
           )
  end

  test "callback hover" do
    text = """
    defmodule MyModule do
      @callback some(integer()) :: atom()
    end
    """

    {line, char} = {1, 13}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\nMyModule.some(integer())\n```\n\n*callback*"
           )
  end

  test "elixir type hover" do
    text = """
    defmodule MyModule do
      @type d :: Date.t()
    end
    """

    {line, char} = {1, 18}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\nDate.t()\n```\n\n*type* [View on hexdocs](https://hexdocs.pm/elixir/#{System.version()}/Date.html#t:t/0)"
           )
  end

  test "erlang function" do
    text = """
    defmodule MyModule do
      def hello() do
        :timer.sleep(1000)
      end
    end
    """

    {line, char} = {2, 10}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(v, "```elixir\n:timer.sleep(")
    # TODO hexdocs and standard lib docs
    assert not String.contains?(
             v,
             "[View on hexdocs]"
           )
  end

  test "keyword" do
    text = """
    defmodule MyModule do
      @type d :: Date.t()
    end
    """

    {line, char} = {0, 19}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\ndo\n```\n\n*reserved word*"
           )
  end

  test "variable" do
    text = """
    defmodule MyModule do
      asdf = 1
    end
    """

    {line, char} = {1, 3}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\nasdf\n```\n\n*variable*"
           )
  end

  test "attribute" do
    text = """
    defmodule MyModule do
      @behaviour :some
    end
    """

    {line, char} = {1, 4}
    parser_context = ParserContextBuilder.from_string(text)

    {line, char} =
      SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

    assert {:ok,
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{kind: "markdown", value: v}
            }} =
             Hover.hover(parser_context, line, char)

    assert String.starts_with?(
             v,
             "```elixir\n@behaviour\n```\n\n*module attribute*"
           )
  end
end
