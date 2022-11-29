defmodule ElixirLS.LanguageServer.Experimental.CodeMod.Diff do
  alias ElixirLS.LanguageServer.Experimental.CodeUnit
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Position
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit

  @spec diff(String.t(), String.t()) :: [TextEdit.t()]
  def diff(source, dest) do
    source
    |> String.myers_difference(dest)
    |> to_text_edits()
  end

  defp to_text_edits(difference) do
    {_, edits} =
      Enum.reduce(difference, {{0, 0}, []}, fn {diff_type, diff_string}, {position, edits} ->
        apply_diff(diff_type, position, diff_string, edits)
      end)

    edits
    |> Enum.reduce([], &collapse/2)

    # Sorting in reverse by start character and line ensures edits are applied back to front on
    # throughout a document which means deletes won't affect subsequent edits and mess up their
    # start / end ranges
    # TODO: This would be more easily accomplished by adding edits to a list for each line
    # and then flat_mapping the result
    |> Enum.sort_by(fn edit -> {edit.range.start.line, edit.range.start.character} end, :desc)
  end

  # This collapses a delete and an an insert that are adjacent to one another
  # into a single insert, changing the delete to insert the text from the
  # insert rather than ""
  # It's a small optimization, but it was in the original
  defp collapse(
         %TextEdit{
           new_text: "",
           range: %Range{
             end: %Position{character: same_character, line: same_line}
           }
         } = delete_edit,
         [
           %TextEdit{
             new_text: insert_text,
             range:
               %Range{
                 start: %Position{character: same_character, line: same_line}
               } = _insert_edit
           }
           | rest
         ]
       )
       when byte_size(insert_text) > 0 do
    collapsed_edit = %TextEdit{delete_edit | new_text: insert_text}
    [collapsed_edit | rest]
  end

  defp collapse(%TextEdit{} = edit, edits) do
    [edit | edits]
  end

  defp apply_diff(:eq, position, doc_string, edits) do
    new_position = advance(doc_string, position)
    {new_position, edits}
  end

  defp apply_diff(:del, {line, code_unit} = position, change, edits) do
    after_pos = {edit_end_line, edit_end_unit} = advance(change, position)
    {after_pos, [edit("", line, code_unit, edit_end_line, edit_end_unit) | edits]}
  end

  defp apply_diff(:ins, {line, code_unit} = position, change, edits) do
    {advance(change, position), [edit(change, line, code_unit, line, code_unit) | edits]}
  end

  def advance(<<>>, position) do
    position
  end

  for ending <- ["\r\n", "\r", "\n"] do
    def advance(<<unquote(ending), rest::binary>>, {line, _unit}) do
      advance(rest, {line + 1, 0})
    end
  end

  def advance(<<c, rest::binary>>, {line, unit}) when c < 128 do
    advance(rest, {line, unit + 1})
  end

  def advance(<<c::utf8, rest::binary>>, {line, unit}) do
    increment = CodeUnit.count(:utf16, <<c::utf8>>)
    advance(rest, {line, unit + increment})
  end

  defp edit(text, start_line, start_unit, end_line, end_unit) do
    TextEdit.new(
      new_text: text,
      range:
        Range.new(
          start: Position.new(line: start_line, character: start_unit),
          end: Position.new(line: end_line, character: end_unit)
        )
    )
  end
end
