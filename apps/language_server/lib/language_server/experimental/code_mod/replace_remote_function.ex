defmodule ElixirLS.LanguageServer.Experimental.CodeMod.ReplaceRemoteFunction do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Text
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit

  @spec text_edits(String.t(), Ast.t(), [[atom()]], atom(), atom()) ::
          {:ok, [TextEdit.t()]} | :error
  def text_edits(original_text, ast, possible_aliases, name, suggestion) do
    with {:ok, transformed} <-
           apply_transforms(original_text, ast, possible_aliases, name, suggestion) do
      {:ok, Diff.diff(original_text, transformed)}
    end
  end

  defp apply_transforms(line_text, quoted_ast, possible_aliases, name, suggestion) do
    leading_indent = Text.leading_indent(line_text)

    updated_ast =
      Macro.postwalk(quoted_ast, fn
        {:., function_meta, [{:__aliases__, module_meta, module_alias}, ^name]} ->
          if module_alias in possible_aliases do
            {:., function_meta, [{:__aliases__, module_meta, module_alias}, suggestion]}
          else
            {:., function_meta, [{:__aliases__, module_meta, module_alias}, name]}
          end

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
