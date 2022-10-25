defmodule ElixirLS.LanguageServer.Experimental.SourceFile.LineParser do
  import ElixirLS.LanguageServer.Experimental.SourceFile.Line

  @endings ["\r\n", "\n", "\r"]

  def parse("", _starting_index) do
    []
  end

  def parse(text, starting_index) when is_binary(text) do
    text
    |> do_split(starting_index, [], true, [])
    |> Enum.reduce([], fn line(text: iodata) = orig, acc ->
      new_line = line(orig, text: IO.iodata_to_binary(iodata))
      [new_line | acc]
    end)
  end

  for ending <- @endings do
    defp do_split(<<unquote(ending)>>, line_number, curr_line, curr_line_is_ascii, lines) do
      [new_line(line_number, curr_line, curr_line_is_ascii, unquote(ending)) | lines]
    end

    defp do_split(
           <<unquote(ending), rest::binary>>,
           line_number,
           curr_line,
           curr_line_is_ascii,
           lines
         ) do
      do_split(rest, line_number + 1, [], true, [
        new_line(line_number, curr_line, curr_line_is_ascii, unquote(ending)) | lines
      ])
    end
  end

  defp do_split(<<c, rest::binary>>, line_number, curr_line, curr_line_is_ascii, lines)
       when c <= 128 do
    do_split(rest, line_number, [curr_line, c], curr_line_is_ascii, lines)
  end

  defp do_split(<<c, rest::binary>>, line_number, curr_line, _, lines) do
    do_split(rest, line_number, [curr_line, c], false, lines)
  end

  defp do_split(<<>>, _line_number, [], _, lines) do
    # this is a line at the end of the document with no content
    # I'm choosing not to represent it as a line to simplify things
    # and to make the line count what we expect
    lines
  end

  defp do_split(<<>>, line_number, curr_line, curr_line_is_ascii, lines) do
    # file doesn't end with a newline
    [new_line(line_number, curr_line, curr_line_is_ascii, "") | lines]
  end

  defp new_line(line_number, line_text, is_ascii?, ending) do
    line(line_number: line_number, text: line_text, ending: ending, ascii?: is_ascii?)
  end
end
