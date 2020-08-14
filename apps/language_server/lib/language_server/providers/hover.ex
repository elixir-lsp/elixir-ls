defmodule ElixirLS.LanguageServer.Providers.Hover do
  alias ElixirLS.LanguageServer.SourceFile

  @moduledoc """
  Hover provider utilizing Elixir Sense
  """

  def hover(text, line, character) do
    response =
      case ElixirSense.docs(text, line + 1, character + 1) do
        %{subject: ""} ->
          nil

        %{subject: subject, docs: docs} ->
          line_text = Enum.at(SourceFile.lines(text), line)
          range = highlight_range(line_text, line, character, subject)

          %{"contents" => contents(docs), "range" => range}
      end

    {:ok, response}
  end

  ## Helpers

  defp highlight_range(line_text, line, character, substr) do
    regex_ranges =
      Regex.scan(
        Regex.recompile!(~r/\b#{Regex.escape(substr)}\b/),
        line_text,
        capture: :first,
        return: :index
      )

    Enum.find_value(regex_ranges, fn
      [{start, length}] when start <= character and character <= start + length ->
        %{
          "start" => %{"line" => line, "character" => start},
          "end" => %{"line" => line, "character" => start + length}
        }

      _ ->
        nil
    end)
  end

  defp contents(%{docs: "No documentation available\n"}) do
    []
  end

  defp contents(%{docs: markdown}) do
    %{
      kind: "markdown",
      value: markdown
    }
  end
end
