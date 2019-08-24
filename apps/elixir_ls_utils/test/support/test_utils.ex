defmodule ElixirLS.Utils.TestUtils do
  import ExUnit.Assertions

  def assert_has_cursor_char(text, line, character) do
    char =
      String.split(text, "\n")
      |> Enum.at(line + 1)
      |> String.graphemes()
      |> Enum.at(character)

    assert char == "^"
  end
end
