defmodule ElixirLS.LanguageServer.Providers.OnTypeFormatting do
  @moduledoc """
  Provides smart automatic insertion of "end" when the user hits enter after "do" or "->"

  We insert the "end" if terminators are incorrect and adding "end" would fix them, or if the next
  non-blank line is indented less than the line where the user hit "enter" or is indented the same
  but does not start with "end" or "else"
  """

  alias ElixirLS.LanguageServer.SourceFile
  import ElixirLS.LanguageServer.Protocol

  def format(%SourceFile{} = source_file, line, character, "\n", _options) do
    lines = SourceFile.lines(source_file)
    prev_line = Enum.at(lines, line - 1)

    prev_tokens = tokens(prev_line)

    if Enum.at(prev_tokens, -1) in ["do", "->"] and not terminators_correct?(source_file.text) do
      prev_indentation = indentation(prev_line)
      prev_indentation_length = String.length(prev_indentation)

      # Use contents and indentation of the next line to help us guess whether to insert an "end"
      indentation_suggests_edit? =
        if Enum.at(prev_tokens, -1) == "do" or "fn" in prev_tokens do
          next_line = Enum.find(Enum.slice(lines, (line + 1)..-1), "", &(!blank?(&1)))
          next_tokens = tokens(next_line)
          next_indentation_length = String.length(indentation(next_line))

          next_indentation_length < prev_indentation_length or
            (next_indentation_length == prev_indentation_length and
               Enum.at(next_tokens, 0) not in ["end", "else"])
        else
          false
        end

      # Apply the proposed change to the current text so we can see if it fixes terminators
      insert_on_next_line? = blank?(Enum.at(lines, line)) and line != Enum.count(lines) - 1
      {range, new_text} = insert_end_edit(prev_indentation, line, character, insert_on_next_line?)
      edited_text = SourceFile.apply_edit(source_file.text, range, new_text)

      if indentation_suggests_edit? or terminators_correct?(edited_text) do
        {:ok, [%{"range" => range, "newText" => new_text}]}
      else
        {:ok, nil}
      end
    else
      {:ok, nil}
    end
  end

  # If terminators are already correct, we never want to insert an "end" that would break them.
  # If terminators are incorrect, we check if inserting an "end" will fix them.
  defp terminators_correct?(text) do
    match?({:ok, _}, Code.string_to_quoted(text))
  end

  defp tokens(line) do
    Regex.scan(Regex.recompile!(~r/(?:->)|(?:\w+)/), line) |> List.flatten()
  end

  defp indentation(line) do
    [indentation] = Regex.run(Regex.recompile!(~r/^\s*/), line)
    indentation
  end

  defp blank?(line), do: String.trim(line) == ""

  # In VS Code, currently, the cursor jumps strangely if the current line is blank and we try to
  # insert a newline at the current position, so unfortunately, we have to check for that.
  defp insert_end_edit(indentation, line, character, insert_on_next_line?) do
    if insert_on_next_line? do
      {range(line + 1, 0, line + 1, 0), "#{indentation}end\n"}
    else
      {range(line, character, line, character), "\n#{indentation}end"}
    end
  end
end
