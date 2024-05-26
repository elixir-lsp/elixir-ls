defmodule ElixirLS.LanguageServer.Providers.CodeMod.Diff do
  alias ElixirLS.LanguageServer.CodeUnit
  alias ElixirLS.LanguageServer.Protocol.TextEdit

  import ElixirLS.LanguageServer.Protocol

  @spec diff(String.t(), String.t()) :: [TextEdit.t()]
  def diff(source, dest) do
    source
    |> String.myers_difference(dest)
    |> to_text_edits()
  end

  defp to_text_edits(difference) do
    {_, {current_line, prev_lines}} =
      Enum.reduce(difference, {{0, 0}, {[], []}}, fn
        {diff_type, diff_string}, {position, edits} ->
          apply_diff(diff_type, position, diff_string, edits)
      end)

    [current_line | prev_lines]
    |> Enum.flat_map(fn line_edits ->
      line_edits
      |> Enum.reduce([], &collapse/2)
      |> Enum.reverse()
    end)
  end

  # This collapses a delete and an insert that are adjacent to one another
  # into a single insert, changing the delete to insert the text from the
  # insert rather than ""
  defp collapse(
         %TextEdit{
           newText: "",
           range: %{
             "end" => %{"character" => same_character, "line" => same_line}
           }
         } = delete_edit,
         [
           %TextEdit{
             newText: insert_text,
             range:
               %{
                 "start" => %{"character" => same_character, "line" => same_line}
               } = _insert_edit
           }
           | rest
         ]
       )
       when byte_size(insert_text) > 0 do
    collapsed_edit = %TextEdit{delete_edit | newText: insert_text}
    [collapsed_edit | rest]
  end

  defp collapse(%TextEdit{} = edit, edits) do
    [edit | edits]
  end

  defp apply_diff(:eq, position, doc_string, edits) do
    advance(doc_string, position, edits)
  end

  defp apply_diff(:del, {line, code_unit} = position, change, edits) do
    {after_pos, {current_line, prev_lines}} = advance(change, position, edits)
    {edit_end_line, edit_end_unit} = after_pos
    current_line = [edit("", line, code_unit, edit_end_line, edit_end_unit) | current_line]
    {after_pos, {current_line, prev_lines}}
  end

  defp apply_diff(:ins, {line, code_unit} = position, change, {current_line, prev_lines}) do
    current_line = [edit(change, line, code_unit, line, code_unit) | current_line]
    # When inserting, the insert itself does not exist in source, so there is no need to advance
    {position, {current_line, prev_lines}}
  end

  defp advance(<<>>, position, edits) do
    {position, edits}
  end

  for ending <- ["\r\n", "\r", "\n"] do
    defp advance(<<unquote(ending), rest::binary>>, {line, _unit}, {current_line, prev_lines}) do
      edits = {[], [current_line | prev_lines]}
      advance(rest, {line + 1, 0}, edits)
    end
  end

  defp advance(<<c, rest::binary>>, {line, unit}, edits) when c < 128 do
    advance(rest, {line, unit + 1}, edits)
  end

  defp advance(<<c::utf8, rest::binary>>, {line, unit}, edits) do
    increment = CodeUnit.count(:utf16, <<c::utf8>>)
    advance(rest, {line, unit + increment}, edits)
  end

  defp edit(text, start_line, start_unit, end_line, end_unit) do
    %TextEdit{
      newText: text,
      range: range(start_line, start_unit, end_line, end_unit)
    }
  end
end
