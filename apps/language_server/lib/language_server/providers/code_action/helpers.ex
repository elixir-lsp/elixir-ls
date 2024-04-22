defmodule ElixirLS.LanguageServer.Providers.CodeAction.Helpers do
  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.Providers.CodeMod.Diff

  @spec to_text_edits(String.t(), String.t()) :: {:ok, [TextEdit.t()]} | :error
  def to_text_edits(unformatted_text, updated_text) do
    formatted_text =
      unformatted_text
      |> Code.format_string!(line_length: :infinity)
      |> IO.iodata_to_binary()

    change_text_edits = Diff.diff(formatted_text, updated_text)

    with {:ok, changed_line} <- changed_line(change_text_edits) do
      is_line_formatted =
        unformatted_text
        |> Diff.diff(formatted_text)
        |> Enum.filter(&near_changed_line(&1, changed_line))
        |> Enum.empty?()

      if is_line_formatted do
        {:ok, change_text_edits}
      else
        :error
      end
    end
  end

  defp changed_line(text_edits) do
    lines =
      text_edits
      |> Enum.flat_map(fn %TextEdit{range: range} ->
        [range["start"]["line"], range["end"]["line"]]
      end)
      |> Enum.uniq()

    case lines do
      [line] -> {:ok, line}
      _ -> :error
    end
  end

  defp near_changed_line(%TextEdit{range: range}, changed_line) do
    changed_line_neighborhood = [changed_line - 1, changed_line, changed_line + 1]

    range["start"]["line"] in changed_line_neighborhood or
      range["end"]["line"] in changed_line_neighborhood
  end

  @spec update_line(TextEdit.t(), non_neg_integer()) :: TextEdit.t()
  def update_line(
        %TextEdit{range: %{"start" => start_line, "end" => end_line}} = text_edit,
        line_number
      ) do
    %TextEdit{
      text_edit
      | range: %{
          "start" => %{start_line | "line" => line_number},
          "end" => %{end_line | "line" => line_number}
        }
    }
  end
end
