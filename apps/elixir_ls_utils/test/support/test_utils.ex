defmodule ElixirLS.Utils.TestUtils do
  import ExUnit.Assertions

  def assert_has_cursor_char(text, line, character) do
    char =
      String.split(text, ["\r\n", "\r", "\n"])
      |> Enum.at(line + 1)
      |> String.graphemes()
      |> Enum.at(character)

    assert char == "^"
  end

  def assert_match_list(list1, list2) do
    assert Enum.sort(list1) == Enum.sort(list2)
  end
end
