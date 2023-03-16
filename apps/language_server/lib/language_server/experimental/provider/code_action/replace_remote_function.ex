defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction do
  @moduledoc """
  Code actions that replace unknown remote function with ones suggested by the warning message
  """

  alias ElixirLS.LanguageServer.Experimental.CodeMod
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionResult
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Workspace
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  @function_re ~r/(.*)\/(.*) is undefined or private. .*:\n(.*)/s

  @spec apply(CodeAction.t()) :: [CodeActionResult.t()]
  def apply(%CodeAction{} = code_action) do
    source_file = code_action.source_file
    diagnostics = get_in(code_action, [:context, :diagnostics]) || []

    diagnostics
    |> Enum.flat_map(fn %Diagnostic{} = diagnostic ->
      one_based_line = extract_start_line(diagnostic)
      suggestions = extract_suggestions(diagnostic.message)

      with {:ok, module_aliases, name} <- extract_function(diagnostic.message),
           {:ok, replies} <-
             build_code_actions(source_file, one_based_line, module_aliases, name, suggestions) do
        replies
      else
        _ -> []
      end
    end)
  end

  defp extract_function(message) do
    case Regex.scan(@function_re, message) do
      [[_, full_name, _, _]] ->
        {module_aliases, name} = separate_module_from_name(full_name)
        {:ok, module_aliases, name}

      _ ->
        :error
    end
  end

  defp separate_module_from_name(full_name) do
    {name, module_aliases} =
      full_name
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)
      |> List.pop_at(-1)

    {module_aliases, name}
  end

  @suggestion_re ~r/\* .*\/[\d]+/
  defp extract_suggestions(message) do
    case Regex.scan(@function_re, message) do
      [[_, _, arity, suggestions_string]] ->
        @suggestion_re
        |> Regex.scan(suggestions_string)
        |> Enum.flat_map(fn [suggestion] ->
          case String.split(suggestion, [" ", "/"]) do
            ["*", name, ^arity] -> [String.to_atom(name)]
            _ -> []
          end
        end)

      _ ->
        []
    end
  end

  defp extract_start_line(%Diagnostic{} = diagnostic) do
    diagnostic.range.start.line
  end

  defp build_code_actions(
         %SourceFile{} = source_file,
         one_based_line,
         module_aliases,
         name,
         suggestions
       ) do
    with {:ok, line_text} <- SourceFile.fetch_text_at(source_file, one_based_line),
         {:ok, line_ast} <- Ast.from(line_text),
         {:ok, edits_per_suggestion} <-
           text_edits_per_suggestion(line_text, line_ast, module_aliases, name, suggestions) do
      case edits_per_suggestion do
        [] ->
          :error

        [_ | _] ->
          replies =
            Enum.map(edits_per_suggestion, fn {text_edits, suggestion} ->
              text_edits = Enum.map(text_edits, &update_line(&1, one_based_line))

              CodeActionResult.new(
                title: construct_title(module_aliases, suggestion),
                kind: :quick_fix,
                edit: Workspace.Edit.new(changes: %{source_file.uri => text_edits})
              )
            end)

          {:ok, replies}
      end
    end
  end

  defp text_edits_per_suggestion(line_text, line_ast, module_aliases, name, suggestions) do
    suggestions
    |> Enum.reduce_while([], fn suggestion, acc ->
      case CodeMod.ReplaceRemoteFunction.text_edits(
             line_text,
             line_ast,
             module_aliases,
             name,
             suggestion
           ) do
        {:ok, []} -> {:cont, acc}
        {:ok, edits} -> {:cont, [{edits, suggestion} | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      edits -> {:ok, edits}
    end
  end

  defp update_line(%TextEdit{} = text_edit, line_number) do
    text_edit
    |> put_in([:range, :start, :line], line_number - 1)
    |> put_in([:range, :end, :line], line_number - 1)
  end

  defp construct_title(module_aliases, suggestion) do
    module_string = Enum.map_join(module_aliases, ".", &Atom.to_string/1)

    "Replace with #{module_string}.#{suggestion}"
  end
end
