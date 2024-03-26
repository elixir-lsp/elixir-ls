defmodule ElixirLS.LanguageServer.Providers.CodeAction.ReplaceWithUnderscore do
  @moduledoc """
  A code action that prefixes unused variables with an underscore
  """

  use ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.Providers.CodeAction.CodeActionResult
  alias ElixirLS.LanguageServer.Providers.CodeMod.Ast
  alias ElixirLS.LanguageServer.SourceFile

  import ElixirLS.LanguageServer.Providers.CodeAction.Helpers

  @spec apply(SourceFile.t(), String.t(), [map()]) :: [CodeActionResult.t()]
  def apply(%SourceFile{} = source_file, uri, diagnostics) do
    Enum.flat_map(diagnostics, fn diagnostic ->
      with {:ok, variable_name, line} <- extract_variable_and_line(diagnostic),
           {:ok, reply} <- build_code_action(source_file, uri, line, variable_name) do
        [reply]
      else
        :error ->
          []
      end
    end)
  end

  defp extract_variable_and_line(diagnostic) do
    with {:ok, variable_name} <- extract_variable_name(diagnostic["message"]) do
      {:ok, variable_name, diagnostic["range"]["start"]["line"]}
    end
  end

  @variable_re ~r/variable "([^"]+)" is unused/
  defp extract_variable_name(message) do
    case Regex.scan(@variable_re, message) do
      [[_, variable_name]] ->
        {:ok, String.to_atom(variable_name)}

      _ ->
        :error
    end
  end

  defp build_code_action(%SourceFile{} = source_file, uri, line, variable_name) do
    case text_edits(source_file, line, variable_name) do
      {:ok, [_ | _] = text_edits} ->
        text_edits = Enum.map(text_edits, &update_line(&1, line))

        reply =
          CodeActionResult.new(
            "Rename to _#{variable_name}",
            "quickfix",
            text_edits,
            uri
          )

        {:ok, reply}

      :error ->
        :error
    end
  end

  @spec text_edits(SourceFile.t(), non_neg_integer(), atom()) :: {:ok, [TextEdit.t()]} | :error
  defp text_edits(%SourceFile{text: unformatted_text} = source_file, line, variable_name) do
    with {:ok, updated_text} <- apply_transform(source_file, line, variable_name) do
      to_text_edits(unformatted_text, updated_text)
    end
  end

  defp apply_transform(source_file, line, unused_variable_name) do
    with {:ok, ast, comments} <- Ast.from(source_file) do
      underscored_variable_name = :"_#{unused_variable_name}"

      one_based_line = line + 1

      updated_text =
        ast
        |> Macro.postwalk(fn
          {^unused_variable_name, [line: ^one_based_line], nil} ->
            {underscored_variable_name, [line: one_based_line], nil}

          other ->
            other
        end)
        |> Ast.to_string(comments)

      {:ok, updated_text}
    end
  end
end
