defmodule ElixirLS.LanguageServer.Experimental.CodeMod.ReplaceRemoteFunction do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit

  @spec text_edits(String.t(), Ast.t(), [atom()], atom(), atom()) ::
          {:ok, [TextEdit.t()]} | :error
  def text_edits(original_text, ast, module, name, suggestion) do
    with {:ok, transformed} <- apply_transforms(original_text, ast, module, name, suggestion) do
      {:ok, Diff.diff(original_text, transformed)}
    end
  end

  defp apply_transforms(line_text, quoted_ast, module, name, suggestion) do
    leading_indent = leading_indent(line_text)

    updated_ast =
      Macro.postwalk(quoted_ast, fn
        {:., meta1, [{:__aliases__, meta2, ^module}, ^name]} ->
          {:., meta1, [{:__aliases__, meta2, module}, suggestion]}

        other ->
          other
      end)

    if updated_ast != quoted_ast do
      updated_ast
      |> Ast.to_string()
      # We're dealing with a single error on a single line.
      # If the line doesn't compile (like it has a do with no end), ElixirSense
      # adds additional lines do documents with errors, so take the first line, as it's
      # the properly transformed source
      |> fetch_line(0)
      |> case do
        {:ok, text} ->
          {:ok, "#{leading_indent}#{text}"}

        error ->
          error
      end
    else
      :error
    end
  end

  @indent_regex ~r/^\s+/
  defp leading_indent(line_text) do
    case Regex.scan(@indent_regex, line_text) do
      [indent] -> indent
      _ -> ""
    end
  end

  defp fetch_line(message, line_number) do
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
