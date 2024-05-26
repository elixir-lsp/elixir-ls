defmodule ElixirLS.LanguageServer.Providers.CodeMod.Text do
  @indent_regex ~r/^\s+/
  @comment_regex ~r/\s*#.*/

  @spec leading_indent(String.t()) :: String.t()
  def leading_indent(line_text) do
    case Regex.scan(@indent_regex, line_text) do
      [indent] -> indent
      _ -> ""
    end
  end

  @spec trailing_comment(String.t()) :: String.t()
  def trailing_comment(line_text) do
    case Regex.scan(@comment_regex, line_text) do
      [comment] -> comment
      _ -> ""
    end
  end

  @spec fetch_line(String.t(), non_neg_integer()) :: {:ok, String.t()} | :error
  def fetch_line(message, line_number) do
    line =
      message
      |> String.split(["\r\n", "\r", "\n"])
      |> Enum.at(line_number)

    case line do
      nil -> :error
      other -> {:ok, other}
    end
  end
end
