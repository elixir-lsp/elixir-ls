defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceLocalFunction do
  alias ElixirLS.LanguageServer.Experimental.CodeMod
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionResult
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Workspace
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser

  @function_re ~r/undefined function ([^\/]*)\/([0-9]*) \(expected (.*) to define such a function or for it to be imported, but none are available\)/

  @spec apply(CodeAction.t()) :: [CodeActionResult.t()]
  def apply(%CodeAction{} = code_action) do
    source_file = code_action.source_file
    diagnostics = get_in(code_action, [:context, :diagnostics]) || []

    diagnostics
    |> Enum.flat_map(fn %Diagnostic{} = diagnostic ->
      one_based_line = extract_start_line(diagnostic)

      with {:ok, module, function, arity} <- parse_message(diagnostic.message),
           suggestions = create_suggestions(source_file, one_based_line, module, function, arity),
           {:ok, replies} <-
             build_code_actions(source_file, one_based_line, function, suggestions) do
        replies
      else
        _ -> []
      end
    end)
  end

  defp extract_start_line(%Diagnostic{} = diagnostic) do
    diagnostic.range.start.line
  end

  defp parse_message(message) do
    case Regex.scan(@function_re, message) do
      [[_, function, arity, module]] ->
        {:ok, Module.concat([module]), String.to_atom(function), String.to_integer(arity)}

      _ ->
        :error
    end
  end

  @generated_functions [:__info__, :module_info]
  @threshold 0.77
  @max_suggestions 5

  defp create_suggestions(%SourceFile{} = source_file, one_based_line, module, function, arity) do
    source_string = SourceFile.to_string(source_file)

    %Metadata{mods_funs_to_positions: module_functions} =
      Parser.parse_string(source_string, true, true, one_based_line)

    module_functions
    |> Enum.flat_map(fn
      {{^module, suggestion, ^arity}, _info} ->
        distance =
          function
          |> Atom.to_string()
          |> String.jaro_distance(Atom.to_string(suggestion))

        [{suggestion, distance}]

      _ ->
        []
    end)
    |> Enum.reject(&(elem(&1, 0) in @generated_functions))
    |> Enum.filter(&(elem(&1, 1) >= @threshold))
    |> Enum.sort(&(elem(&1, 1) >= elem(&2, 1)))
    |> Enum.take(@max_suggestions)
    |> Enum.sort(&(elem(&1, 0) <= elem(&2, 0)))
    |> Enum.map(&elem(&1, 0))
  end

  defp build_code_actions(%SourceFile{} = source_file, one_based_line, function, suggestions) do
    with {:ok, line_text} <- SourceFile.fetch_text_at(source_file, one_based_line),
         {:ok, line_ast} <- Ast.from(line_text),
         {:ok, edits_per_suggestion} <-
           text_edits_per_suggestion(line_text, line_ast, function, suggestions) do
      case edits_per_suggestion do
        [] ->
          :error

        [_ | _] ->
          replies =
            Enum.map(edits_per_suggestion, fn {text_edits, suggestion} ->
              text_edits = Enum.map(text_edits, &update_line(&1, one_based_line))

              CodeActionResult.new(
                title: construct_title(suggestion),
                kind: :quick_fix,
                edit: Workspace.Edit.new(changes: %{source_file.uri => text_edits})
              )
            end)

          {:ok, replies}
      end
    end
  end

  defp text_edits_per_suggestion(line_text, line_ast, function, suggestions) do
    suggestions
    |> Enum.reduce_while([], fn suggestion, acc ->
      case CodeMod.ReplaceLocalFunction.text_edits(
             line_text,
             line_ast,
             function,
             suggestion
           ) do
        {:ok, []} -> {:cont, acc}
        {:ok, edits} -> {:cont, [{edits, suggestion} | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      edits -> {:ok, Enum.reverse(edits)}
    end
  end

  defp update_line(%TextEdit{} = text_edit, line_number) do
    text_edit
    |> put_in([:range, :start, :line], line_number - 1)
    |> put_in([:range, :end, :line], line_number - 1)
  end

  defp construct_title(suggestion) do
    "Replace with #{suggestion}"
  end
end
