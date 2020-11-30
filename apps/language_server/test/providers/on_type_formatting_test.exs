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

  test "don't  insert `end` after `do:`" do
    text = """
    for a <- b, do:
    """

    assert {:ok, nil} = OnTypeFormatting.format(%SourceFile{text: text}, 1, 0, "\n", [])
  end
end
