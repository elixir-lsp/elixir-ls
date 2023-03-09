defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction do
  @moduledoc """
  Code actions that replace unknown remote function with ones suggested by the warning message
  """

  alias ElixirLS.LanguageServer.Experimental.CodeMod
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionResult
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Workspace
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  @pattern ~r/(.*)\/(.*) is undefined or private. .*:\n(.*)/s

  @spec pattern() :: Regex.t()
  def pattern, do: @pattern

  @spec apply(SourceFile.t(), Diagnostic.t()) :: [CodeActionResult.t()]
  def apply(source_file, diagnostic) do
    with {:ok, module, name} <- extract_function(diagnostic.message),
         {:ok, suggestions} <- extract_suggestions(diagnostic.message),
         one_based_line = extract_line(diagnostic),
         {:ok, replies} <-
           build_code_actions(source_file, one_based_line, module, name, suggestions) do
      replies
    else
      _ ->
        []
    end
  end

  defp extract_function(message) do
    case Regex.scan(@pattern, message) do
      [[_, full_name, _, _]] ->
        {module, name} = separate_module_from_name(full_name)
        {:ok, module, name}

      _ ->
        :error
    end
  end

  defp separate_module_from_name(full_name) do
    {name, module} =
      full_name
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)
      |> List.pop_at(-1)

    {module, name}
  end

  @suggestion_pattern ~r/\* .*\/[\d]+/
  defp extract_suggestions(message) do
    case Regex.scan(@pattern, message) do
      [[_, _, arity, suggestions_string]] ->
        suggestions =
          @suggestion_pattern
          |> Regex.scan(suggestions_string)
          |> Enum.flat_map(fn [suggestion] ->
            case String.split(suggestion, [" ", "/"]) do
              ["*", name, ^arity] -> [String.to_atom(name)]
              _ -> []
            end
          end)

        {:ok, suggestions}

      _ ->
        :error
    end
  end

  defp extract_line(%Diagnostic{} = diagnostic) do
    diagnostic.range.start.line
  end

  defp build_code_actions(%SourceFile{} = source_file, one_based_line, module, name, suggestions) do
    with {:ok, line_text} <- SourceFile.fetch_text_at(source_file, one_based_line),
         {:ok, line_ast} <- Ast.from(line_text),
         {:ok, edits_per_suggestion} <-
           text_edits_per_suggestion(line_text, line_ast, module, name, suggestions) do
      case edits_per_suggestion do
        [] ->
          :error

        [_ | _] ->
          edits_per_suggestion =
            Enum.map(edits_per_suggestion, fn {text_edits, suggestion} ->
              text_edits = Enum.map(text_edits, &update_line(&1, one_based_line))
              {text_edits, suggestion}
            end)

          replies =
            Enum.map(edits_per_suggestion, fn {text_edits, function_name} ->
              CodeActionResult.new(
                title: construct_title(module, function_name),
                kind: :quick_fix,
                edit: Workspace.Edit.new(changes: %{source_file.uri => text_edits})
              )
            end)

          {:ok, replies}
      end
    end
  end

  defp text_edits_per_suggestion(line_text, line_ast, module, name, suggestions) do
    Enum.reduce(suggestions, {:ok, []}, fn
      suggestion, {:ok, edits_per_suggestions} ->
        case CodeMod.ReplaceRemoteFunction.text_edits(
               line_text,
               line_ast,
               module,
               name,
               suggestion
             ) do
          {:ok, []} -> {:ok, edits_per_suggestions}
          {:ok, text_edits} -> {:ok, [{text_edits, suggestion} | edits_per_suggestions]}
          :error -> :error
        end

      _suggestion, :error ->
        :error
    end)
  end

  defp update_line(%TextEdit{} = text_edit, line_number) do
    text_edit
    |> put_in([:range, :start, :line], line_number - 1)
    |> put_in([:range, :end, :line], line_number - 1)
  end

  defp construct_title(module_list, function_name) do
    module_string =
      module_list
      |> Enum.map(fn module ->
        module
        |> Atom.to_string()
        |> String.trim_leading("Elixir.")
      end)
      |> Enum.join(".")

    "Replace function with #{module_string}.#{function_name}"
  end
end
