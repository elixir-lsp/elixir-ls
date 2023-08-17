defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.AddAlias do
  alias ElixirLS.LanguageServer.Experimental.CodeMod
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.State.Env
  alias LSP.Requests.CodeAction
  alias LSP.Types.CodeAction, as: CodeActionResult
  alias LSP.Types.Diagnostic
  alias LSP.Types.TextEdit
  alias LSP.Types.Workspace

  @undefined_module_re ~r/(.*) is undefined \(module (.*) is not available or is yet to be defined\)/s
  @unknown_struct_re ~r/\(CompileError\) (.*).__struct__\/1 is undefined, cannot expand struct (.*). Make sure the struct name is correct./s

  @spec apply(CodeAction.t()) :: [CodeActionResult.t()]
  def apply(%CodeAction{} = code_action) do
    source_file = code_action.source_file
    diagnostics = get_in(code_action, [:context, :diagnostics]) || []

    Enum.flat_map(diagnostics, fn %Diagnostic{} = diagnostic ->
      one_based_line = extract_start_line(diagnostic)

      with {:ok, module_string} <- parse_message(diagnostic.message),
           true <- module_present?(source_file, one_based_line, module_string),
           {:ok, suggestions} <- create_suggestions(module_string, source_file, one_based_line),
           {:ok, replies} <- build_code_actions(source_file, one_based_line, suggestions) do
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
    case Regex.scan(@undefined_module_re, message) do
      [[_message, _function, module]] ->
        {:ok, module}

      _ ->
        case Regex.scan(@unknown_struct_re, message) do
          [[_message, module, module]] -> {:ok, module}
          _ -> :error
        end
    end
  end

  defp module_present?(source_file, one_based_line, module_string) do
    module = module_to_alias_list(module_string)

    with {:ok, line_text} <- SourceFile.fetch_text_at(source_file, one_based_line),
         {:ok, line_ast} <- Ast.from(line_text) do
      line_ast
      |> Macro.postwalk(false, fn
        {:., _fun_meta, [{:__aliases__, _aliases_meta, ^module} | _fun]} = ast, _acc ->
          {ast, true}

        {:%, _struct_meta, [{:__aliases__, _aliases_meta, ^module} | _fields]} = ast, _acc ->
          {ast, true}

        other_ast, acc ->
          {other_ast, acc}
      end)
      |> elem(1)
    end
  end

  @max_suggestions 3
  defp create_suggestions(module_string, source_file, one_based_line) do
    with {:ok, current_namespace} <- current_module_namespace(source_file, one_based_line) do
      suggestions =
        ElixirSense.all_modules()
        |> Enum.filter(&String.ends_with?(&1, "." <> module_string))
        |> Enum.sort_by(&same_namespace?(&1, current_namespace))
        |> Enum.take(@max_suggestions)
        |> Enum.map(&module_to_alias_list/1)

      {:ok, suggestions}
    end
  end

  defp same_namespace?(suggested_module_string, current_namespace) do
    suggested_module_namespace =
      suggested_module_string
      |> module_to_alias_list()
      |> List.first()
      |> Atom.to_string()

    current_namespace == suggested_module_namespace
  end

  defp current_module_namespace(source_file, one_based_line) do
    %Metadata{lines_to_env: lines_to_env} =
      source_file
      |> SourceFile.to_string()
      |> Parser.parse_string(true, true, one_based_line)

    case Map.get(lines_to_env, one_based_line) do
      nil ->
        :error

      %Env{module: module} ->
        namespace =
          module
          |> module_to_alias_list()
          |> List.first()
          |> Atom.to_string()

        {:ok, namespace}
    end
  end

  defp module_to_alias_list(module) when is_atom(module) do
    case Atom.to_string(module) do
      "Elixir." <> module_string -> module_to_alias_list(module_string)
      module_string -> module_to_alias_list(module_string)
    end
  end

  defp module_to_alias_list(module) when is_binary(module) do
    module
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end

  defp build_code_actions(source_file, one_based_line, suggestions) do
    with {:ok, edits_per_suggestion} <-
           text_edits_per_suggestion(source_file, one_based_line, suggestions) do
      case edits_per_suggestion do
        [] ->
          :error

        [_ | _] ->
          replies =
            Enum.map(edits_per_suggestion, fn {text_edits, alias_line, suggestion} ->
              text_edits = Enum.map(text_edits, &update_line(&1, alias_line))

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

  defp text_edits_per_suggestion(source_file, one_based_line, suggestions) do
    suggestions
    |> Enum.reduce_while([], fn suggestion, acc ->
      case CodeMod.AddAlias.text_edits(source_file, one_based_line, suggestion) do
        {:ok, [], _alias_line} -> {:cont, acc}
        {:ok, edits, alias_line} -> {:cont, [{edits, alias_line, suggestion} | acc]}
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

  defp construct_title(suggestion) do
    module_string = Enum.map_join(suggestion, ".", &Atom.to_string/1)

    "Add alias #{module_string}"
  end
end
