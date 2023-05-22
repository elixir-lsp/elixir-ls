defmodule ElixirLS.LanguageServer.Experimental.CodeMod.ReplaceModule do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Text
  alias LSP.Types.TextEdit

  @spec text_edits(String.t(), Ast.t(), [atom()], [atom()]) :: {:ok, [TextEdit.t()]} | :error
  def text_edits(original_text, ast, module, suggestion) do
    with {:ok, transformed} <- apply_transforms(original_text, ast, module, suggestion) do
      {:ok, Diff.diff(original_text, transformed)}
    end
  end

  defp apply_transforms(line_text, quoted_ast, module, suggestion) do
    leading_indent = Text.leading_indent(line_text)

    updated_ast =
      Macro.postwalk(quoted_ast, fn
        {:__aliases__, meta, ^module} -> {:__aliases__, meta, suggestion}
        other -> other
      end)

    if updated_ast != quoted_ast do
      updated_ast
      |> Ast.to_string()
      # We're dealing with a single error on a single line.
      # If the line doesn't compile (like it has a do with no end), ElixirSense
      # adds additional lines do documents with errors, so take the first line, as it's
      # the properly transformed source
      |> Text.fetch_line(0)
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
end
