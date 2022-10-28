defmodule ElixirLS.LanguageServer.Experimental.Format.DiffTest do
  alias ElixirLS.LanguageServer.Experimental.Format.Diff
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Position
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit

  import Diff
  use ExUnit.Case

  def edit(start_line, start_code_unit, end_line, end_code_unit, replacement) do
    TextEdit.new(
      new_text: replacement,
      range:
        Range.new(
          start: Position.new(character: start_code_unit, line: start_line),
          end: Position.new(character: end_code_unit, line: end_line)
        )
    )
  end

  describe "single line ascii diffs" do
    test "a deletion at the start" do
      orig = "  hello"
      final = "hello"

      assert [edit] = diff(orig, final)
      assert edit(0, 0, 0, 2, "") == edit
    end

    test "appending in the middle" do
      orig = "hello"
      final = "heyello"

      assert [edit] = diff(orig, final)
      assert edit(0, 2, 0, 2, "ye") == edit
    end

    test "deleting in the middle" do
      orig = "hello"
      final = "heo"

      assert [edit] = diff(orig, final)
      assert edit(0, 2, 0, 4, "") == edit
    end

    test "inserting after a delete" do
      orig = "hello"
      final = "helvetica went"

      # this is collapsed into a single edit of an
      # insert that spans the delete and the insert
      assert [edit] = diff(orig, final)
      assert edit(0, 3, 0, 5, "vetica went") == edit
    end
  end

  describe "multi line ascii diffs" do
    test "multi-line deletion at the start" do
      orig =
        """
        none
        two
        hello
        """
        |> String.trim()

      final = "hello"

      assert [edit] = diff(orig, final)
      assert edit(0, 0, 2, 0, "") == edit
    end

    test "multi-line appending in the middle" do
      orig = "hello"
      final = "he\n\n ye\n\nllo"

      assert [edit] = diff(orig, final)
      assert edit(0, 2, 0, 2, "\n\n ye\n\n") == edit
    end

    test "deleting multiple lines in the middle" do
      orig =
        """
        hello
        there
        people
        goodbye
        """
        |> String.trim()

      final = "hellogoodbye"

      assert [edit] = diff(orig, final)
      assert edit(0, 5, 3, 0, "") == edit
    end

    test "deletions keep indentation" do
      orig =
        """
        hello
        there


          people
        """
        |> String.trim()

      final =
        """
        hello
        there
          people
        """
        |> String.trim()

      assert [edit] = diff(orig, final)
      assert edit(2, 0, 4, 0, "") == edit
    end
  end

  describe "single line emoji" do
    test "deleting after" do
      orig = ~S[{"🎸",   "after"}]
      final = ~S[{"🎸", "after"}]

      assert [edit] = diff(orig, final)
      assert edit(0, 7, 0, 9, "") == edit
    end

    test "inserting in the middle" do
      orig = ~S[🎸🎸]
      final = ~S[🎸🎺🎸]

      assert [edit] = diff(orig, final)
      assert edit(0, 2, 0, 2, "🎺") == edit
    end

    test "deleting in the middle" do
      orig = ~S[🎸🎺🎺🎸]
      final = ~S[🎸🎸]
      assert [edit] = diff(orig, final)

      assert edit(0, 2, 0, 6, "") == edit
    end
  end

  describe("multi line emoji") do
  end
end
