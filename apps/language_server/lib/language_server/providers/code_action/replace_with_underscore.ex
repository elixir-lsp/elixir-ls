defmodule ElixirLS.LanguageServer.Providers.CodeAction.ReplaceWithUnderscore do
  @moduledoc """
  A code action that prefixes unused variables with an underscore
  """

  use ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.Providers.CodeAction.CodeActionResult
  alias ElixirLS.LanguageServer.Providers.CodeMod.Ast
  alias ElixirLS.LanguageServer.Providers.CodeMod.Diff
  alias ElixirLS.LanguageServer.Providers.CodeMod.Text
  alias ElixirLS.LanguageServer.SourceFile

  import ElixirLS.LanguageServer.Providers.CodeAction.Helpers

  @spec apply(SourceFile.t(), String.t(), [map()]) :: [CodeActionResult.t()]
  def apply(%SourceFile{} = source_file, uri, diagnostics) do
    Enum.flat_map(diagnostics, fn diagnostic ->
      with {:ok, variable_name, line_number} <- extract_variable_and_line(diagnostic),
           {:ok, reply} <- build_code_action(source_file, uri, line_number, variable_name) do
        [reply]
      else
        _ ->
          []
      end
    end)
  end

  defp extract_variable_and_line(diagnostic) do
    message = diagnostic_to_message(diagnostic)

    with {:ok, variable_name} <- extract_variable_name(message) do
      {:ok, variable_name, diagnostic["range"]["start"]["line"]}
    end
  end

  defp extract_variable_name(message) do
    case Regex.scan(~r/variable "([^"]+)" is unused/, message) do
      [[_, variable_name]] ->
        {:ok, String.to_atom(variable_name)}

      _ ->
        :error
    end
  end

  defp build_code_action(%SourceFile{} = source_file, uri, line_number, variable_name) do
    with {:ok, line_text} <- fetch_line(source_file, line_number),
         {:ok, line_ast} <- Ast.from(line_text),
         {:ok, text_edits} <- text_edits(line_text, line_ast, variable_name) do
      case text_edits do
        [] ->
          :error

        [_ | _] ->
          text_edits = Enum.map(text_edits, &update_line(&1, line_number))

          reply =
            CodeActionResult.new(
              "Rename to _#{variable_name}",
              "quickfix",
              text_edits,
              uri
            )

          {:ok, reply}
      end
    end
  end

  defp fetch_line(%SourceFile{} = source_file, line_number) do
    lines = SourceFile.lines(source_file)

    if length(lines) > line_number do
      {:ok, Enum.at(lines, line_number)}
    else
      :error
    end
  end

  @spec text_edits(String.t(), Ast.t(), atom()) :: {:ok, [TextEdit.t()]} | :error
  defp text_edits(original_text, ast, variable_name) do
    with {:ok, transformed} <- apply_transform(original_text, ast, variable_name) do
      {:ok, to_text_edits(original_text, transformed)}
    end
  end

  defp apply_transform(line_text, quoted_ast, unused_variable_name) do
    underscored_variable_name = :"_#{unused_variable_name}"
    leading_indent = Text.leading_indent(line_text)

    Macro.postwalk(quoted_ast, fn
      {^unused_variable_name, meta, nil} ->
        {underscored_variable_name, meta, nil}

      other ->
        other
    end)
    |> to_one_line_string()
    |> case do
      {:ok, text} ->
        {:ok, "#{leading_indent}#{text}"}

      :error ->
        :error
    end
  end

  defp to_text_edits(original_text, fixed_text) do
    original_text
    |> Diff.diff(fixed_text)
    |> Enum.filter(&(&1.newText == "_"))
  end
end
