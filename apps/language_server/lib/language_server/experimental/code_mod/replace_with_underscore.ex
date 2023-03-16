defmodule ElixirLS.LanguageServer.Experimental.CodeMod.ReplaceWithUnderscore do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Text
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit

  @spec text_edits(String.t(), Ast.t(), String.t() | atom) :: {:ok, [TextEdit.t()]} | :error
  def text_edits(original_text, ast, variable_name) do
    variable_name = ensure_atom(variable_name)

    with {:ok, transformed} <- apply_transform(original_text, ast, variable_name) do
      {:ok, to_text_edits(original_text, transformed)}
    end
  end

  defp to_text_edits(orig_text, fixed_text) do
    orig_text
    |> Diff.diff(fixed_text)
    |> Enum.filter(&(&1.new_text == "_"))
  end

  defp ensure_atom(variable_name) when is_binary(variable_name) do
    String.to_atom(variable_name)
  end

  defp ensure_atom(variable_name) when is_atom(variable_name) do
    variable_name
  end

  defp apply_transform(line_text, quoted_ast, unused_variable_name) do
    underscored_variable_name = :"_#{unused_variable_name}"
    leading_indent = Text.leading_indent(line_text)

    Macro.postwalk(quoted_ast, fn
      {^unused_variable_name, meta, context} ->
        {underscored_variable_name, meta, context}

      other ->
        other
    end)
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
  end
end
