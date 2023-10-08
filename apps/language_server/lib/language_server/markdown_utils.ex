defmodule ElixirLS.LanguageServer.MarkdownUtils do
  # Find the lowest heading level in the fragment
  defp lowest_heading_level(fragment) do
    case Regex.scan(~r/(#+)/, fragment) do
      [] ->
        nil

      matches ->
        matches
        |> Enum.map(fn [_, heading] -> String.length(heading) end)
        |> Enum.min()
    end
  end

  # Adjust heading levels of an embedded markdown fragment
  def adjust_headings(fragment, base_level) do
    min_level = lowest_heading_level(fragment)

    if min_level do
      level_difference = base_level + 1 - min_level

      Regex.replace(~r/(#+)/, fragment, fn _, capture ->
        adjusted_level = String.length(capture) + level_difference
        String.duplicate("#", adjusted_level)
      end)
    else
      fragment
    end
  end

  def join_with_horizontal_rule(list) do
    Enum.map_join(list, "\n\n---\n\n", fn lines ->
      lines
      |> String.replace_leading("\r\n", "")
      |> String.replace_leading("\n", "")
      |> String.replace_trailing("\r\n", "")
      |> String.replace_trailing("\n", "")
    end) <> "\n"
  end
end
