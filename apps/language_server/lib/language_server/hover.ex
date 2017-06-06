defmodule ElixirLS.LanguageServer.Hover do
  @moduledoc """
  Hover provider utilizing Elixir Sense
  """

  def hover(text, line, character) do
    %{subject: subject, docs: docs} = 
      ElixirSense.docs(text, line + 1, character + 1)

    line_text = Enum.at(String.split(text, "\n"), line)
    range = highlight_range(line_text, line, character, subject)

    %{"contents" => contents(docs), "range" => range}
  end

  ## Helpers

  defp highlight_range(_line_text, _line, _character, nil) do
    nil
  end

  defp highlight_range(line_text, line, character, substr) do
    regex_ranges = Regex.scan(~r/\b#{Regex.escape(substr)}\b/, line_text, capture: :first, return: :index)
    Enum.find_value regex_ranges, fn
      [{start, length}] when start <= character and character <= start + length ->
        %{"start" => %{"line" => line, "character" => start},
          "end" => %{"line" => line, "character" => start + length}}
      _ ->
        nil
    end
  end

  defp contents(%{docs: "No documentation available"}) do
    []
  end

  defp contents(%{docs: markdown}) do
    markdown
  end

end