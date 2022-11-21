defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore do
  @moduledoc """
  A code action that prefixes unused variables with an underscore
  """
  alias ElixirLS.LanguageServer.Experimental.Format.Diff
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionResult
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Position
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.WorkspaceEdit
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  @spec apply(CodeAction.t()) :: [CodeActionReply.t()]
  def apply(%CodeAction{} = code_action) do
    source_file = code_action.source_file
    diagnostics = code_action.context.diagnostics

    Enum.reduce(diagnostics, [], fn %Diagnostic{} = diagnostic, actions ->
      with {:ok, variable_name, one_based_line} <- extract_variable_and_line(diagnostic),
           {:ok, reply} <- build_code_action(source_file, one_based_line, variable_name) do
        [reply | actions]
      else
        _ ->
          actions
      end
    end)
    |> Enum.reverse()
  end

  defp build_code_action(%SourceFile{} = source_file, one_based_line, variable_name) do
    with {:ok, line_text} <- SourceFile.fetch_text_at(source_file, one_based_line),
         {:ok, line_ast} <- ElixirSense.string_to_quoted(line_text, 0),
         {:ok, transformed} <- apply_transform(line_ast, variable_name) do
      text_edits =
        line_text
        |> to_text_edits(transformed)
        |> update_lines(one_based_line)
        |> Enum.filter(fn edit -> edit.new_text == "_" end)

      reply =
        CodeActionResult.new(
          title: "Rename to _#{variable_name}",
          kind: :quick_fix,
          edit: WorkspaceEdit.new(changes: %{source_file.uri => text_edits})
        )

      {:ok, reply}
    end
  end

  defp to_text_edits(orig_text, fixed_text) do
    orig_text
    |> Diff.diff(fixed_text)
    |> Enum.filter(fn edit -> edit.new_text == "_" end)
  end

  defp update_lines(text_edits, one_based_line) do
    Enum.map(text_edits, fn %TextEdit{} = text_edit ->
      start_line = text_edit.range.start.line + one_based_line - 1
      end_line = text_edit.range.end.line + one_based_line - 1

      %TextEdit{
        text_edit
        | range: %Range{
            start: %Position{text_edit.range.start | line: start_line},
            end: %Position{text_edit.range.end | line: end_line}
          }
      }
    end)
  end

  defp apply_transform(quoted_ast, unused_variable_name) do
    underscored_variable_name = :"_#{unused_variable_name}"

    Macro.postwalk(quoted_ast, fn
      {^unused_variable_name, meta, context} ->
        {underscored_variable_name, meta, context}

      other ->
        other
    end)
    |> Macro.to_string()
    # We're dealing with a single error on a single line.
    # If the line doesn't compile (like it has a do with no end), ElixirSense
    # adds additional lines do documents with errors, so take the first line, as it's
    # the properly transformed source
    |> fetch_line(0)
  end

  defp extract_variable_and_line(%Diagnostic{} = diagnostic) do
    with {:ok, variable_name} <- extract_variable_name(diagnostic.message),
         {:ok, line} <- extract_line(diagnostic) do
      {:ok, variable_name, line}
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

  defp extract_line(%Diagnostic{} = diagnostic) do
    {:ok, diagnostic.range.start.line}
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
