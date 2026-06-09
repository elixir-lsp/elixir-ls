defmodule ElixirLS.LanguageServer.Providers.CodeMod.Text do
  @spec leading_indent(String.t()) :: String.t()
  def leading_indent(line_text) do
    case Regex.run(~r/^\s+/, line_text) do
      [indent] when is_binary(indent) -> indent
      _ -> ""
    end
  end

  @spec trailing_comment(String.t()) :: String.t()
  def trailing_comment(line_text) do
    # Use the tokenizer-aware parser so a `#` inside a string/charlist literal
    # is not mistaken for a comment.
    case Code.string_to_quoted_with_comments(line_text) do
      {:ok, _ast, [_ | _] = comments} ->
        %{text: text} = List.last(comments)
        " " <> text

      _ ->
        ""
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
