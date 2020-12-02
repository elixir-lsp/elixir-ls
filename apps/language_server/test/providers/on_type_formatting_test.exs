defmodule ElixirLS.LanguageServer.Providers.OnTypeFormattingTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.OnTypeFormatting
  alias ElixirLS.LanguageServer.SourceFile

  test "insert `end` after `do`" do
    text = """
    for a <- b do
    """

    assert {:ok,
            [
              %{
                "newText" => "\nend",
                "range" => %{
                  "start" => %{"character" => 0, "line" => 1},
                  "end" => %{"character" => 0, "line" => 1}
                }
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
              %{
                "newText" => "\n  end",
                "range" => %{
                  "start" => %{"character" => 0, "line" => 2},
                  "end" => %{"character" => 0, "line" => 2}
                }
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
