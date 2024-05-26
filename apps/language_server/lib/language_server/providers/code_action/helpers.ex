defmodule ElixirLS.LanguageServer.Providers.CodeAction.Helpers do
  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.Providers.CodeMod.Ast
  alias ElixirLS.LanguageServer.Providers.CodeMod.Text

  @spec update_line(TextEdit.t(), non_neg_integer()) :: TextEdit.t()
  def update_line(
        %TextEdit{range: %{"start" => start_line, "end" => end_line}} = text_edit,
        line_number
      ) do
    %TextEdit{
      text_edit
      | range: %{
          "start" => %{start_line | "line" => line_number},
          "end" => %{end_line | "line" => line_number}
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

  @do_regex ~r/\s*do\s*/
  defp maybe_recover_one_line_do(updated_text, {_name, context, _children} = _updated_ast) do
    wrong_do_end_conditions = [
      not Keyword.has_key?(context, :do),
      not Keyword.has_key?(context, :end),
      Regex.match?(@do_regex, updated_text),
      String.ends_with?(updated_text, "\nend")
    ]

    if Enum.all?(wrong_do_end_conditions) do
      updated_text
      |> String.replace(@do_regex, ", do: ")
      |> String.trim_trailing("\nend")
    else
      updated_text
    end
  end

  defp maybe_recover_one_line_do(updated_text, _updated_ast) do
    updated_text
  end
end
