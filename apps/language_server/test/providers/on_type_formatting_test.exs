defmodule ElixirLS.LanguageServer.Providers.OnTypeFormattingTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.OnTypeFormatting
  alias ElixirLS.LanguageServer.SourceFile
  import ElixirLS.LanguageServer.RangeUtils

  test "insert `end` after `do`" do
    text = """
    for a <- b do
    """

    assert {:ok,
            [
              %GenLSP.Structures.TextEdit{
                new_text: "\nend",
                range: range(1, 0, 1, 0)
              }
            ]} = OnTypeFormatting.format(%SourceFile{text: text}, 1, 0, "\n", [])
  end

  test "insert `end` after def `do`" do
    text = """
    defmodule TestA do
      def myfun(a) do
    end
    """

    assert {:ok,
            [
              %GenLSP.Structures.TextEdit{
                new_text: "\n  end",
                range: range(2, 0, 2, 0)
              }
            ]} = OnTypeFormatting.format(%SourceFile{text: text}, 2, 0, "\n", [])
  end

  test "don't  insert `end` after `do:`" do
    text = """
    for a <- b, do:
    """

    assert {:ok, nil} = OnTypeFormatting.format(%SourceFile{text: text}, 1, 0, "\n", [])
  end

  test "don't insert `end` after def `do: a`" do
    text = """
    defmodule TestA do
      def myfun(a), do: a
    end
    """

    assert {:ok, nil} = OnTypeFormatting.format(%SourceFile{text: text}, 2, 0, "\n", [])
  end
end
