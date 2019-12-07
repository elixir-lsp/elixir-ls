defmodule ElixirLS.Test.TextLoc do
  def annotate(path, line, character) do
    with {:ok, text} <- read_file_line(path, line) do
      pointer_line = String.duplicate(" ", character) <> "^\n"
      {:ok, text <> pointer_line}
    end
  end

  defmacro annotate_assert(path, line, character, expected) do
    quote do
      assert {:ok, actual} =
               ElixirLS.Test.TextLoc.annotate(unquote(path), unquote(line), unquote(character))

      if actual == unquote(expected) do
        assert actual == unquote(expected)
      else
        IO.puts("Acutal is:")
        IO.puts(["\"\"\"", "\n", actual, "\"\"\""])
        assert actual == unquote(expected)
      end
    end
  end

  def read_file_line(path, line) do
    File.stream!(path, [:read, :utf8], :line)
    |> Stream.drop(line)
    |> Enum.take(1)
    |> hd()
    |> wrap_in_ok()
  rescue
    e in File.Error ->
      {:error, e}
  end

  defp wrap_in_ok(input), do: {:ok, input}
end
