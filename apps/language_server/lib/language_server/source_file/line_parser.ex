defmodule ElixirLS.LanguageServer.SourceFile.LineParser do
  import ElixirLS.LanguageServer.SourceFile.Line

  @endings ["\r\n", "\n", "\r"]

  def parse("", _starting_index) do
    []
  end

  def parse(text, starting_index) when is_binary(text) do
    text
    |> do_split(starting_index, [], [])
    |> Enum.reduce([], fn line(text: iodata) = orig, acc ->
      new_line = line(orig, text: IO.iodata_to_binary(iodata))
      [new_line | acc]
    end)
  end

  for ending <- @endings do
    defp do_split(<<unquote(ending)>>, line_number, curr_line, lines) do
      [new_line(line_number, curr_line, unquote(ending)) | lines]
    end

    defp do_split(<<unquote(ending), rest::binary>>, line_number, curr_line, lines) do
      do_split(rest, line_number + 1, [], [
        new_line(line_number, curr_line, unquote(ending)) | lines
      ])
    end
  end

  defp do_split(<<c, rest::binary>>, line_number, line_text, lines) do
    do_split(rest, line_number, [line_text, c], lines)
  end

  defp do_split(<<>>, _line_number, [], lines) do
    # this is a line at the end of the document with no content
    # I'm choosing not to represent it as a line to simplify things
    # and to make the line count what we expect
    lines
  end

  defp do_split(<<>>, line_number, line_text, lines) do
    # file doesn't end with a newline
    [new_line(line_number, line_text, "") | lines]
  end

  defp new_line(line_number, line_text, ending) do
    line(line_number: line_number, text: line_text, ending: ending)
  end
end
