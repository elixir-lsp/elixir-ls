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

  defmacrop assert_range(ranges, expected) do
    quote do
      assert Enum.any?(unquote(ranges), &(&1 == unquote(expected)))
    end
  end

  describe "token pair ranges" do
    test "brackets nested cursor inside" do
      text = """
      [{1, 2}, 3]
      """

      ranges = get_ranges(text, 0, 3)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # [] outside
      assert_range(ranges, range(0, 0, 0, 11))
      # [] inside
      assert_range(ranges, range(0, 1, 0, 10))
      # {} outside
      assert_range(ranges, range(0, 1, 0, 7))
      # {} inside
      assert_range(ranges, range(0, 2, 0, 6))
    end

    test "brackets cursor inside left" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 1)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # {} outside
      assert_range(ranges, range(0, 0, 0, 6))
      # {} inside
      assert_range(ranges, range(0, 1, 0, 5))
    end

    test "brackets cursor inside right" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 5)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # {} outside
      assert_range(ranges, range(0, 0, 0, 6))
      # {} inside
      assert_range(ranges, range(0, 1, 0, 5))
    end

    test "brackets cursor outside left" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 0)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # {} outside
      assert_range(ranges, range(0, 0, 0, 6))
    end

    test "brackets cursor outside right" do
      text = """
      {1, 2}
      """

      ranges = get_ranges(text, 0, 0)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # {} outside
      assert_range(ranges, range(0, 0, 0, 6))
    end
  end

  test "alias" do
    text = """
    Some.Module.Foo
    """

    ranges = get_ranges(text, 0, 1)

    # full range
    assert_range(ranges, range(0, 0, 1, 0))
    # full alias
    assert_range(ranges, range(0, 0, 0, 15))
  end

  test "remote call" do
    text = """
    Some.Module.Foo.some_fun()
    """

    ranges = get_ranges(text, 0, 17)

    # full range
    assert_range(ranges, range(0, 0, 1, 0))
    # full remote call
    assert_range(ranges, range(0, 0, 0, 26))
    # full remote call
    assert_range(ranges, range(0, 0, 0, 24))
  end

  describe "comments" do
    test "single comment" do
      text = """
        # some comment
      """

      ranges = get_ranges(text, 0, 5)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full line
      assert_range(ranges, range(0, 0, 0, 16))
      # from #
      assert_range(ranges, range(0, 2, 0, 16))
    end

    test "comment block on first line" do
      text = """
        # some comment
        # continues here
        # ends here
      """

      ranges = get_ranges(text, 0, 5)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full lines
      assert_range(ranges, range(0, 0, 2, 13))
      # from #
      assert_range(ranges, range(0, 2, 2, 13))
      # from # first line
      assert_range(ranges, range(0, 2, 0, 16))
    end

    test "comment block on middle line" do
      text = """
        # some comment
        # continues here
        # ends here
      """

      ranges = get_ranges(text, 1, 5)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full lines
      assert_range(ranges, range(0, 0, 2, 13))
      # from #
      assert_range(ranges, range(0, 2, 2, 13))
      # full # middle line
      assert_range(ranges, range(1, 0, 1, 18))
      # from # middle line
      assert_range(ranges, range(1, 2, 1, 18))
    end

    test "comment block on last line" do
      text = """
        # some comment
        # continues here
        # ends here
      """

      ranges = get_ranges(text, 2, 5)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full lines
      assert_range(ranges, range(0, 0, 2, 13))
      # from #
      assert_range(ranges, range(0, 2, 2, 13))
      # full # last line
      assert_range(ranges, range(2, 0, 2, 13))
      # from # last line
      assert_range(ranges, range(2, 2, 2, 13))
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
      assert_range(ranges, range(0, 0, 4, 0))
      # outside do-end
      assert_range(ranges, range(0, 0, 3, 3))
      # inside do-end
      assert_range(ranges, range(1, 0, 2, 4))
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
      assert_range(ranges, range(0, 0, 4, 0))
      # outside do-end
      assert_range(ranges, range(0, 0, 3, 3))
      # do
      assert_range(ranges, range(0, 0, 0, 2))
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
      assert_range(ranges, range(0, 0, 4, 0))
      # outside do-end
      assert_range(ranges, range(0, 0, 3, 3))
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
      assert_range(ranges, range(0, 0, 4, 0))
      # outside do-end
      assert_range(ranges, range(0, 0, 3, 3))
      # end
      assert_range(ranges, range(3, 0, 3, 3))
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
      assert_range(ranges, range(0, 0, 4, 0))
      # outside do-end
      assert_range(ranges, range(0, 0, 3, 3))
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
    assert_range(ranges, range(0, 0, 5, 0))
    # defmodule
    assert_range(ranges, range(0, 0, 4, 3))
    # def
    assert_range(ranges, range(1, 2, 3, 5))
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
      assert_range(ranges, range(0, 0, 3, 0))
      # full @doc
      assert_range(ranges, range(0, 0, 2, 3))
    end

    test "heredoc" do
      text = """
      @doc \"""
      This is a doc
      \"""
      """

      ranges = get_ranges(text, 1, 0)
      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full @doc
      assert_range(ranges, range(0, 0, 2, 3))
    end

    test "charlist heredoc" do
      text = """
      @doc '''
      This is a doc
      '''
      """

      ranges = get_ranges(text, 1, 0)
      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full @doc
      assert_range(ranges, range(0, 0, 2, 3))
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
      assert_range(ranges, range(0, 0, 3, 0))
      # full literal
      assert_range(ranges, range(0, 2, 2, 3))
    end

    test "number" do
      text = """
      1234 + 43
      """

      ranges = get_ranges(text, 0, 0)
      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full expression
      assert_range(ranges, range(0, 0, 0, 9))
      # full literal
      assert_range(ranges, range(0, 0, 0, 4))
    end

    test "atom" do
      text = """
      :asdfghj
      """

      ranges = get_ranges(text, 0, 1)
      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full literal
      assert_range(ranges, range(0, 0, 0, 8))
    end

    test "interpolated string" do
      text = """
      "asdf\#{inspect([1, 2])}gfds"
      """

      ranges = get_ranges(text, 0, 17)
      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full literal
      assert_range(ranges, range(0, 0, 0, 28))
      # full interpolation
      assert_range(ranges, range(0, 5, 0, 23))
      # inside #{}
      assert_range(ranges, range(0, 7, 0, 22))
      # inside ()
      assert_range(ranges, range(0, 15, 0, 21))
      # literal
      # NOTE AST only matching - no tokens inside interpolation
      assert_range(ranges, range(0, 16, 0, 17))
    end
  end

  test "utf16" do
    text = """
    "foooob🏳️‍🌈rbaz"
    """

    ranges = get_ranges(text, 0, 1)

    # full range
    assert_range(ranges, range(0, 0, 1, 0))
    # utf16 range
    assert range(0, 0, 0, end_character) = Enum.at(ranges, 1)

    assert end_character == SourceFile.lines(text) |> Enum.at(0) |> SourceFile.line_length_utf16()
  end

  describe "struct" do
    test "inside {}" do
      text = """
      %My.Struct{
        some: 123,
        other: "abc"
      }
      """

      ranges = get_ranges(text, 1, 2)

      # full range
      assert_range(ranges, range(0, 0, 4, 0))
      # full struct
      assert_range(ranges, range(0, 0, 3, 1))
      # full {} outside
      assert_range(ranges, range(0, 10, 3, 1))
      # full {} inside
      assert_range(ranges, range(0, 11, 3, 0))
      # full lines:
      assert_range(ranges, range(1, 0, 2, 14))
      # full lines trimmed
      assert_range(ranges, range(1, 2, 2, 14))
      # some: 123
      assert_range(ranges, range(1, 2, 1, 11))
      # some
      assert_range(ranges, range(1, 2, 1, 6))
    end

    test "on alias" do
      text = """
      %My.Struct{
        some: 123,
        other: "abc"
      }
      """

      ranges = get_ranges(text, 0, 2)

      # full range
      assert_range(ranges, range(0, 0, 4, 0))
      # full struct
      assert_range(ranges, range(0, 0, 3, 1))
      # %My.Struct
      assert_range(ranges, range(0, 0, 0, 10))
      # My.Struct
      assert_range(ranges, range(0, 1, 0, 10))
    end
  end

  describe "comma separated" do
    test "before first ," do
      text = """
      fun(%My{} = my, keyword: 123, other: [:a, ""])
      """

      ranges = get_ranges(text, 0, 6)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full call
      assert_range(ranges, range(0, 0, 0, 46))
      # full () outside
      assert_range(ranges, range(0, 3, 0, 46))
      # full () inside
      assert_range(ranges, range(0, 4, 0, 45))
      # %My{} = my
      assert_range(ranges, range(0, 4, 0, 14))
    end

    test "between ," do
      text = """
      fun(%My{} = my, keyword: 123, other: [:a, ""])
      """

      ranges = get_ranges(text, 0, 18)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full call
      assert_range(ranges, range(0, 0, 0, 46))
      # full () outside
      assert_range(ranges, range(0, 3, 0, 46))
      # full () inside
      assert_range(ranges, range(0, 4, 0, 45))
      # keyword: 123
      assert_range(ranges, range(0, 16, 0, 28))
    end

    test "after last ," do
      text = """
      fun(%My{} = my, keyword: 123, other: [:a, ""])
      """

      ranges = get_ranges(text, 0, 31)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full call
      assert_range(ranges, range(0, 0, 0, 46))
      # full () outside
      assert_range(ranges, range(0, 3, 0, 46))
      # full () inside
      assert_range(ranges, range(0, 4, 0, 45))
      # other: [:a, ""]
      assert_range(ranges, range(0, 30, 0, 45))
    end
  end

  describe "case" do
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
      assert_range(ranges, range(0, 0, 7, 0))
      # full b case
      assert_range(ranges, range(3, 2, 5, 10))
      # b block
      assert_range(ranges, range(4, 4, 5, 10))
      # more()
      assert_range(ranges, range(4, 4, 4, 10))
    end

    test "inside case arg" do
      text = """
      case foo do
        {:ok, _} -> :ok
        _ ->
          Logger.error("Foo")
          :error
      end
      """

      ranges = get_ranges(text, 0, 6)

      # full range
      assert_range(ranges, range(0, 0, 6, 0))
      # full case
      assert_range(ranges, range(0, 0, 5, 3))
      # foo
      assert_range(ranges, range(0, 5, 0, 8))
    end

    test "left side of -> single line" do
      text = """
      case foo do
        {:ok, _} -> :ok
        _ ->
          Logger.error("Foo")
          :error
      end
      """

      ranges = get_ranges(text, 1, 3)

      # full range
      assert_range(ranges, range(0, 0, 6, 0))
      # full case
      assert_range(ranges, range(0, 0, 5, 3))
      # do block
      assert_range(ranges, range(0, 9, 5, 3))
      # do block inside
      assert_range(ranges, range(1, 0, 4, 10))
      # do block inside trimmed
      assert_range(ranges, range(1, 2, 4, 10))
      # full expression
      assert_range(ranges, range(1, 2, 1, 17))
      # {:ok, _}
      assert_range(ranges, range(1, 2, 1, 10))
    end

    test "right side of -> single line" do
      text = """
      case foo do
        {:ok, _} -> :ok
        _ ->
          Logger.error("Foo")
          :error
      end
      """

      ranges = get_ranges(text, 1, 16)

      # full range
      assert_range(ranges, range(0, 0, 6, 0))
      # full case
      assert_range(ranges, range(0, 0, 5, 3))
      # do block
      assert_range(ranges, range(0, 9, 5, 3))
      # do block inside
      assert_range(ranges, range(1, 0, 4, 10))
      # do block inside trimmed
      assert_range(ranges, range(1, 2, 4, 10))
      # full expression
      assert_range(ranges, range(1, 2, 1, 17))
      # :ok expression
      assert_range(ranges, range(1, 14, 1, 17))
    end

    test "left side of -> multi line" do
      text = """
      case foo do
        {:ok, _} -> :ok
        %{
          asdf: 1
        } ->
          Logger.error("Foo")
          :error
        _ -> :foo
      end
      """

      ranges = get_ranges(text, 3, 5)

      # full range
      assert_range(ranges, range(0, 0, 9, 0))
      # full case
      assert_range(ranges, range(0, 0, 8, 3))
      # do block
      assert_range(ranges, range(0, 9, 8, 3))
      # case -> expression
      assert_range(ranges, range(2, 2, 6, 10))
      # pattern with ->
      assert_range(ranges, range(2, 2, 4, 6))
      # pattern
      assert_range(ranges, range(2, 2, 4, 3))
    end

    test "right side of -> multi line" do
      text = """
      case foo do
        {:ok, _} -> :ok
        %{
          asdf: 1
        } ->
          Logger.error("Foo")
          :error
        _ -> :foo
      end
      """

      ranges = get_ranges(text, 5, 5)

      # full range
      assert_range(ranges, range(0, 0, 9, 0))
      # full case
      assert_range(ranges, range(0, 0, 8, 3))
      # do block
      assert_range(ranges, range(0, 9, 8, 3))
      # do block inside
      assert_range(ranges, range(1, 0, 7, 11))
      # do block inside trimmed
      assert_range(ranges, range(1, 2, 7, 11))
      # case -> expression
      assert_range(ranges, range(2, 2, 6, 10))
      # full block
      assert_range(ranges, range(5, 4, 6, 10))
    end

    test "right side of -> last expression in do block" do
      text = """
      case foo do
        {:ok, _} -> :ok
        %{
          asdf: 1
        } ->
          Logger.error("Foo")
          :error
        _ -> :foo
      end
      """

      ranges = get_ranges(text, 7, 8)

      # full range
      assert_range(ranges, range(0, 0, 9, 0))
      # full case
      assert_range(ranges, range(0, 0, 8, 3))
      # do block
      assert_range(ranges, range(0, 9, 8, 3))
      # do block inside trimmed
      assert_range(ranges, range(1, 2, 7, 11))
      # case -> expression
      assert_range(ranges, range(7, 2, 7, 11))
      # :foo
      assert_range(ranges, range(7, 7, 7, 11))
    end
  end

  describe "for" do
    test "inside do block" do
      text = """
      for x <- [1, 2, 3], y <- [4, 5, 6] do
        x + y
      end
      """

      ranges = get_ranges(text, 1, 2)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full for
      assert_range(ranges, range(0, 0, 2, 3))
      # do block
      assert_range(ranges, range(0, 35, 2, 3))
      # x + y expression
      assert_range(ranges, range(1, 2, 1, 7))
    end

    test "inside do expression single line" do
      text = """
      for x <- [1, 2, 3], y <- [4, 5, 6], into: %{}, do: x + y
      """

      ranges = get_ranges(text, 0, 51)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full for
      assert_range(ranges, range(0, 0, 0, 56))
      # x + y expression
      assert_range(ranges, range(0, 51, 0, 56))
    end

    test "inside do expression" do
      text = """
      for x <- [1, 2, 3], y <- [4, 5, 6],
        into: %{},
        do: x + y
      """

      ranges = get_ranges(text, 2, 6)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full for expression
      assert_range(ranges, range(0, 0, 2, 11))
      # x + y expression
      assert_range(ranges, range(2, 6, 2, 11))
    end

    test "inside <- expression" do
      text = """
      for x <- [1, 2, 3], y <- [4, 5, 6] do
        x + y
      end
      """

      ranges = get_ranges(text, 0, 10)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full for
      assert_range(ranges, range(0, 0, 2, 3))
      # x <- [1, 2, 3]
      assert_range(ranges, range(0, 4, 0, 18))
      # [1, 2, 3]
      assert_range(ranges, range(0, 9, 0, 18))
    end
  end

  describe "with" do
    test "inside do block" do
      text = """
      with x <- [1, 2, 3], y <- [4, 5, 6] do
        x ++ y
      end
      """

      ranges = get_ranges(text, 1, 2)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full for
      assert_range(ranges, range(0, 0, 2, 3))
      # do block
      assert_range(ranges, range(0, 36, 2, 3))
      # x ++ y expression
      assert_range(ranges, range(1, 2, 1, 8))
    end

    test "inside do expression single line" do
      text = """
      with x <- [1, 2, 3], y <- [4, 5, 6], do: x ++ y
      """

      ranges = get_ranges(text, 0, 51)

      # full range
      assert_range(ranges, range(0, 0, 1, 0))
      # full for
      assert_range(ranges, range(0, 0, 0, 47))
      # x ++ y expression
      assert_range(ranges, range(0, 41, 0, 47))
    end

    test "inside do expression" do
      text = """
      with x <- [1, 2, 3],
        y <- [4, 5, 6],
        do: x ++ y
      """

      ranges = get_ranges(text, 2, 6)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full for expression
      assert_range(ranges, range(0, 0, 2, 12))
      # x ++ y expression
      assert_range(ranges, range(2, 6, 2, 12))
    end

    test "inside <- expression" do
      text = """
      with x <- [1, 2, 3], y <- [4, 5, 6] do
        x ++ y
      end
      """

      ranges = get_ranges(text, 0, 10)

      # full range
      assert_range(ranges, range(0, 0, 3, 0))
      # full for
      assert_range(ranges, range(0, 0, 2, 3))
      # x <- [1, 2, 3]
      assert_range(ranges, range(0, 5, 0, 19))
      # [1, 2, 3]
      assert_range(ranges, range(0, 10, 0, 19))
    end
  end

  describe "if" do
    test "inside condition" do
      text = """
      if a + b > 1 do
        :ok
      else
        :error
      end
      """

      ranges = get_ranges(text, 0, 3)

      # full range
      assert_range(ranges, range(0, 0, 5, 0))
      # full if
      assert_range(ranges, range(0, 0, 4, 3))
      # condition
      assert_range(ranges, range(0, 3, 0, 12))
    end

    test "inside do block" do
      text = """
      if a + b > 1 do
        :ok
      else
        :error
      end
      """

      ranges = get_ranges(text, 1, 2)

      # full range
      assert_range(ranges, range(0, 0, 5, 0))
      # full if
      assert_range(ranges, range(0, 0, 4, 3))
      # do-else
      assert_range(ranges, range(0, 15, 2, 0))
      # :ok
      assert_range(ranges, range(1, 2, 1, 5))
    end

    test "inside else block" do
      text = """
      if a + b > 1 do
        :ok
      else
        :error
      end
      """

      ranges = get_ranges(text, 3, 2)

      # full range
      assert_range(ranges, range(0, 0, 5, 0))
      # full if
      assert_range(ranges, range(0, 0, 4, 3))
      # else-end
      assert_range(ranges, range(2, 0, 4, 3))
      # :error
      assert_range(ranges, range(3, 2, 3, 8))
    end
  end

  test "operators" do
    text = """
    var1 + var2 * var3 > var4 - var5
    """

    ranges = get_ranges(text, 0, 8)

    # full range
    assert_range(ranges, range(0, 0, 1, 0))
    # full expression
    assert_range(ranges, range(0, 0, 0, 32))
    # full left side of operator >
    assert_range(ranges, range(0, 0, 0, 18))
    # var2 * var3
    assert_range(ranges, range(0, 7, 0, 18))
    # var2
    assert_range(ranges, range(0, 7, 0, 11))
  end
end
