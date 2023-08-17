defmodule ElixirLS.LanguageServer.Experimental.CodeMod.AddAlias do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser
  alias LSP.Types.TextEdit

  @spec text_edits(SourceFile.t(), non_neg_integer(), [atom()]) ::
          {:ok, [TextEdit.t()], non_neg_integer()} | :error
  def text_edits(source_file, one_based_line, suggestion) do
    maybe_blank_line_before(source_file, one_based_line)

    with {:ok, {alias_line, alias_column}} <- find_place(source_file, one_based_line),
         {:ok, line_text} <- SourceFile.fetch_text_at(source_file, alias_line),
         {:ok, transformed} <-
           apply_transforms(source_file, alias_line, alias_column, suggestion) do
      {:ok, Diff.diff(line_text, transformed), alias_line}
    end
  end

  defp find_place(source_file, one_based_line) do
    metadata =
      source_file
      |> SourceFile.to_string()
      |> Parser.parse_string(true, true, one_based_line)

    case Metadata.get_position_to_insert_alias(metadata, one_based_line) do
      nil -> :error
      alias_position -> {:ok, alias_position}
    end
  end

  defp apply_transforms(source_file, line, column, suggestion) do
    case SourceFile.fetch_text_at(source_file, line) do
      {:ok, line_text} ->
        leading_indent = String.duplicate(" ", column - 1)

        new_alias_text = Ast.to_string({:alias, [], [{:__aliases__, [], suggestion}]}) <> "\n"

        maybe_blank_line_before = maybe_blank_line_before(source_file, line)
        maybe_blank_line_after = maybe_blank_line_after(line_text)

        {:ok,
         "#{maybe_blank_line_before}#{leading_indent}#{new_alias_text}#{maybe_blank_line_after}#{line_text}"}

      _ ->
        :error
    end
  end

  defp maybe_blank_line_before(source_file, line) do
    if line >= 2 do
      case SourceFile.fetch_text_at(source_file, line - 1) do
        {:ok, previous_line_text} ->
          cond do
            blank?(previous_line_text) -> ""
            contains_alias?(previous_line_text) -> ""
            module_definition?(previous_line_text) -> ""
            true -> "\n"
          end

        _ ->
          "\n"
      end
    else
      ""
    end
  end

  defp maybe_blank_line_after(line_text) do
    cond do
      blank?(line_text) -> ""
      contains_alias?(line_text) -> ""
      true -> "\n"
    end
  end

  defp blank?(line_text) do
    line_text |> String.trim() |> byte_size() == 0
  end

  defp contains_alias?(line_text) do
    case Ast.from(line_text) do
      {:ok, {:alias, _meta, _alias}} -> true
      _ -> false
    end
  end

  defp module_definition?(line_text) do
    case Ast.from(line_text) do
      {:ok, {:defmodule, _meta, _contents}} -> true
      _ -> false
    end
  end
end
