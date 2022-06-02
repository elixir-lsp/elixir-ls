defmodule ElixirLS.LanguageServer.Providers.SelectionRangesTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.SelectionRanges
  alias ElixirLS.LanguageServer.{SourceFile}
  import ElixirLS.LanguageServer.Protocol

  defp get_ranges(text, line, character) do
    SelectionRanges.selection_ranges(text, [%{"line" => line, "character" => character}])
    |> hd
    |> flatten
  end

  defp flatten(range) do
    flatten(range, [])
  end

  defp flatten(nil, acc), do: acc

  defp flatten(%{"range" => range, "parent" => parent}, acc) do
    flatten(parent, [range | acc])
  end

  describe "token pair ranges" do
    test "brackets nested cursor inside" do
      text = """
      [{1, 2}, 3]
      """

      ranges = get_ranges(text, 0, 3)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # [] outside
      assert Enum.at(ranges, 1) == range(0, 0, 0, 11)
      # [] inside
      assert Enum.at(ranges, 2) == range(0, 1, 0, 10)
      # {} outside
      assert Enum.at(ranges, 3) == range(0, 1, 0, 7)
      # {} inside
      assert Enum.at(ranges, 4) == range(0, 2, 0, 6)
    end

    test "brackets cursor inside left" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 1)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # {} outside
      assert Enum.at(ranges, 1) == range(0, 0, 0, 6)
      # {} inside
      assert Enum.at(ranges, 2) == range(0, 1, 0, 5)
    end

    test "brackets cursor inside right" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 5)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # {} outside
      assert Enum.at(ranges, 1) == range(0, 0, 0, 6)
      # {} inside
      assert Enum.at(ranges, 2) == range(0, 1, 0, 5)
    end

    test "brackets cursor outside left" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 0)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # {} outside
      assert Enum.at(ranges, 1) == range(0, 0, 0, 6)
    end

    test "brackets cursor outside right" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 0)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # {} outside
      assert Enum.at(ranges, 1) == range(0, 0, 0, 6)
    end
  end

  test "alias" do
    text = """
    Some.Module.Foo
    """

    ranges = get_ranges(text, 0, 1)

    # full range
    assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
    # full alias
    assert Enum.at(ranges, 1) == range(0, 0, 0, 15)
  end

  test "remote call" do
    text = """
    Some.Module.Foo.some_fun()
    """

    ranges = get_ranges(text, 0, 17)

    # full range
    assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
    # full remote call
    assert Enum.at(ranges, 1) == range(0, 0, 0, 26)
    # full remote call
    assert Enum.at(ranges, 2) == range(0, 0, 0, 24)
  end

  describe "comments" do
    test "single comment" do
      text = """
        # some comment
      """

      ranges = get_ranges(text, 0, 5)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # full line
      assert Enum.at(ranges, 1) == range(0, 0, 0, 16)
      # from #
      assert Enum.at(ranges, 2) == range(0, 2, 0, 16)
    end

    test "comment block on first line" do
      text = """
        # some comment
        # continues here
        # ends here
      """

      ranges = get_ranges(text, 0, 5)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 3, 0)
      # full lines
      assert Enum.at(ranges, 1) == range(0, 0, 2, 13)
      # from #
      assert Enum.at(ranges, 2) == range(0, 2, 2, 13)
      # from # first line
      assert Enum.at(ranges, 3) == range(0, 2, 0, 16)
    end

    test "comment block on middle line" do
      text = """
        # some comment
        # continues here
        # ends here
      """

      ranges = get_ranges(text, 1, 5)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 3, 0)
      # full lines
      assert Enum.at(ranges, 1) == range(0, 0, 2, 13)
      # from #
      assert Enum.at(ranges, 2) == range(0, 2, 2, 13)
      # full # middle line
      assert Enum.at(ranges, 3) == range(1, 0, 1, 18)
      # from # middle line
      assert Enum.at(ranges, 4) == range(1, 2, 1, 18)
    end

    test "comment block on last line" do
      text = """
        # some comment
        # continues here
        # ends here
      """

      ranges = get_ranges(text, 2, 5)

      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 3, 0)
      # full lines
      assert Enum.at(ranges, 1) == range(0, 0, 2, 13)
      # from #
      assert Enum.at(ranges, 2) == range(0, 2, 2, 13)
      # full # last line
      assert Enum.at(ranges, 3) == range(2, 0, 2, 13)
      # from # last line
      assert Enum.at(ranges, 4) == range(2, 2, 2, 13)
    end
  end

  describe "do-end" do
    test "inside" do
      text = """
      do
        1
        24
      end
      """

      ranges = get_ranges(text, 1, 1)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 4, 0)
      # outside do-end
      assert Enum.at(ranges, 1) == range(0, 0, 3, 3)
      # inside do-end
      assert Enum.at(ranges, 3) == range(1, 0, 2, 4)
    end

    test "left from do" do
      text = """
      do
        1
        24
      end
      """

      ranges = get_ranges(text, 0, 0)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 4, 0)
      # outside do-end
      assert Enum.at(ranges, 1) == range(0, 0, 3, 3)
      # do
      assert Enum.at(ranges, 3) == range(0, 0, 0, 2)
    end

    test "right from do" do
      text = """
      do
        1
        24
      end
      """

      ranges = get_ranges(text, 0, 2)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 4, 0)
      # outside do-end
      assert Enum.at(ranges, 1) == range(0, 0, 3, 3)
    end

    test "left from end" do
      text = """
      do
        1
        24
      end
      """

      ranges = get_ranges(text, 3, 0)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 4, 0)
      # outside do-end
      assert Enum.at(ranges, 1) == range(0, 0, 3, 3)
      # end
      assert Enum.at(ranges, 2) == range(3, 0, 3, 3)
    end

    test "right from end" do
      text = """
      do
        1
        24
      end
      """

      ranges = get_ranges(text, 3, 3)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 4, 0)
      # outside do-end
      assert Enum.at(ranges, 1) == range(0, 0, 3, 3)
    end
  end

  test "module and def" do
    text = """
    defmodule Abc do
      def some() do
        :ok
      end
    end
    """

    ranges = get_ranges(text, 2, 4)
    # full range
    assert Enum.at(ranges, 0) == range(0, 0, 5, 0)
    # defmodule
    assert Enum.at(ranges, 1) == range(0, 0, 4, 3)
    # def
    assert Enum.at(ranges, 4) == range(1, 2, 3, 5)
  end

  describe "doc" do
    test "sigil" do
      text = """
      @doc ~S\"""
      This is a doc
      \"""
      """

      ranges = get_ranges(text, 1, 0)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 3, 0)
      # full @doc
      assert Enum.at(ranges, 1) == range(0, 0, 2, 3)
    end

    test "heredoc" do
      text = """
      @doc \"""
      This is a doc
      \"""
      """

      ranges = get_ranges(text, 1, 0)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 3, 0)
      # full @doc
      assert Enum.at(ranges, 1) == range(0, 0, 2, 3)
    end

    test "charlist heredoc" do
      text = """
      @doc '''
      This is a doc
      '''
      """

      ranges = get_ranges(text, 1, 0)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 3, 0)
      # full @doc
      assert Enum.at(ranges, 1) == range(0, 0, 2, 3)
    end
  end

  describe "literals" do
    test "heredoc" do
      text = """
        \"""
      This is a doc
      \"""
      """

      ranges = get_ranges(text, 1, 0)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 3, 0)
      # full literal
      assert Enum.at(ranges, 1) == range(0, 2, 2, 3)
    end

    test "number" do
      text = """
      1234 + 43
      """

      ranges = get_ranges(text, 0, 0)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # full literal
      assert Enum.at(ranges, 1) == range(0, 0, 0, 4)
    end

    test "atom" do
      text = """
      :asdfghj
      """

      ranges = get_ranges(text, 0, 1)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # full literal
      assert Enum.at(ranges, 1) == range(0, 0, 0, 8)
    end

    test "interpolated string" do
      text = """
      "asdf\#{inspect([1, 2])}gfds"
      """

      ranges = get_ranges(text, 0, 17)
      # full range
      assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
      # full literal
      assert Enum.at(ranges, 1) == range(0, 0, 0, 28)
      # full interpolation
      assert Enum.at(ranges, 2) == range(0, 5, 0, 23)
      # inside #{}
      assert Enum.at(ranges, 3) == range(0, 7, 0, 22)
      # inside ()
      assert Enum.at(ranges, 4) == range(0, 15, 0, 21)
      # literal
      # NOTE AST only matching - no tokens inside interpolation
      assert Enum.at(ranges, 5) == range(0, 16, 0, 17)
    end
  end

  test "case" do
    text = """
    case x do
      a ->
        some_fun()
      b ->
        more()
        funs()
    end
    """

    ranges = get_ranges(text, 4, 5)

    # full range
    assert Enum.at(ranges, 0) == range(0, 0, 7, 0)
    # full b case
    assert Enum.at(ranges, 5) == range(3, 2, 5, 10)
    # b block
    assert Enum.at(ranges, 7) == range(4, 4, 5, 10)
    # more()
    assert Enum.at(ranges, 8) == range(4, 4, 4, 10)
  end

  test "utf16" do
    text = """
    "foooob🏳️‍🌈rbaz"
    """

    ranges = get_ranges(text, 0, 1)

    # full range
    assert Enum.at(ranges, 0) == range(0, 0, 1, 0)
    # utf16 range
    assert range(0, 0, 0, end_character) = Enum.at(ranges, 1)

    assert end_character == SourceFile.lines(text) |> Enum.at(0) |> SourceFile.line_length_utf16()
  end
end
