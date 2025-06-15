defmodule ElixirLS.LanguageServer.Providers.CodeAction.Helpers do
  alias ElixirLS.LanguageServer.Providers.CodeMod.Ast
  alias ElixirLS.LanguageServer.Providers.CodeMod.Text

  @spec update_line(GenLSP.Structures.TextEdit.t(), non_neg_integer()) :: GenLSP.Structures.TextEdit.t()
  def update_line(
        %GenLSP.Structures.TextEdit{range: range} = text_edit,
        line_number
      ) do
    %GenLSP.Structures.TextEdit{
      text_edit
      | range: %GenLSP.Structures.Range{
          range
          | start: %GenLSP.Structures.Position{range.start | line: line_number},
            end: %GenLSP.Structures.Position{range.end | line: line_number}
        }
    }
  end

  @spec to_one_line_string(Ast.t()) :: {:ok, String.t()} | :error
  def to_one_line_string(updated_ast) do
    updated_ast
    |> Ast.to_string()
    # We're dealing with a single error on a single line.
    # If the line doesn't compile (like it has a do with no end), ElixirSense
    # adds additional lines to documents with errors. Also, in case of a one-line do,
    # ElixirSense creates do with end from the AST.
    |> maybe_recover_one_line_do(updated_ast)
    |> Text.fetch_line(0)
  end

  defp maybe_recover_one_line_do(updated_text, {_name, context, _children} = _updated_ast) do
    wrong_do_end_conditions = [
      not Keyword.has_key?(context, :do),
      not Keyword.has_key?(context, :end),
      Regex.match?(~r/\s*do\s*/, updated_text),
      String.ends_with?(updated_text, "\nend")
    ]

    if Enum.all?(wrong_do_end_conditions) do
      updated_text
      |> String.replace(~r/\s*do\s*/, ", do: ")
      |> String.trim_trailing("\nend")
    else
      updated_text
    end
  end

  defp maybe_recover_one_line_do(updated_text, _updated_ast) do
    updated_text
  end

  # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#diagnostic
  # message can be string or MarkupContent
  # string
  def diagnostic_to_message(%GenLSP.Structures.Diagnostic{message: message}) when is_binary(message), do: message

  # MarkupContent
  def diagnostic_to_message(%GenLSP.Structures.Diagnostic{message: %GenLSP.Structures.MarkupContent{kind: kind, value: value}})
      when kind in ["plaintext", "markdown"],
      do: value
end
