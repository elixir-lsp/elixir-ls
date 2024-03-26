defmodule ElixirLS.LanguageServer.Providers.CodeAction.ReplaceRemoteFunction do
  @moduledoc """
  Code actions that replace unknown remote function with functions from the same module that have
  similar names
  """

  use ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.Providers.CodeAction.CodeActionResult
  alias ElixirLS.LanguageServer.Providers.CodeMod.Ast
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Core.Parser

  import ElixirLS.LanguageServer.Providers.CodeAction.Helpers

  @spec apply(SourceFile.t(), String.t(), [map()]) :: [CodeActionResult.t()]
  def apply(%SourceFile{} = source_file, uri, diagnostics) do
    Enum.flat_map(diagnostics, fn diagnostic ->
      case extract_function_and_line(diagnostic) do
        {:ok, module, function, arity, line} ->
          suggestions = prepare_suggestions(module, function, arity)

          build_code_actions(source_file, line, module, function, suggestions, uri)

        :error ->
          []
      end
    end)
  end

  defp extract_function_and_line(diagnostic) do
    with {:ok, module, function, arity} <- extract_function(diagnostic["message"]) do
      {:ok, module, function, arity, diagnostic["range"]["start"]["line"]}
    end
  end

  @function_re ~r/(\S+)\/(\d+) is undefined or private. Did you mean:.*/
  defp extract_function(message) do
    with [[_, module_and_function, arity]] <- Regex.scan(@function_re, message),
         {:ok, module, function_name} <- separate_module_from_function(module_and_function) do
      {:ok, module, function_name, String.to_integer(arity)}
    else
      _ ->
        :error
    end
  end

  defp separate_module_from_function(module_and_function) do
    module_and_function
    |> String.split(".")
    |> List.pop_at(-1)
    |> case do
      {function_name, [_ | _] = module_alias} ->
        {:ok, alias_to_module(module_alias), function_name}

      _ ->
        :error
    end
  end

  defp alias_to_module([":" <> erlang_alias]) do
    String.to_atom(erlang_alias)
  end

  defp alias_to_module(module_alias) do
    Module.concat(module_alias)
  end

  @function_threshold 0.77
  @max_suggestions 5
  defp prepare_suggestions(module, function, arity) do
    for {module_function, ^arity} <- module_functions(module),
        distance = module_function |> Atom.to_string() |> String.jaro_distance(function),
        distance >= @function_threshold do
      {distance, module_function}
    end
    |> Enum.sort(:desc)
    |> Enum.take(@max_suggestions)
    |> Enum.map(fn {_distance, module_function} -> module_function end)
  end

  defp module_functions(module) do
    if function_exported?(module, :__info__, 1) do
      module.__info__(:functions)
    else
      module.module_info(:functions)
    end
  end

  defp build_code_actions(%SourceFile{} = source_file, line, module, name, suggestions, uri) do
    suggestions
    |> Enum.reduce([], fn suggestion, acc ->
      case text_edits(source_file, line, module, name, suggestion) do
        {:ok, [_ | _] = text_edits} ->
          text_edits = Enum.map(text_edits, &update_line(&1, line))

          code_action =
            CodeActionResult.new("Rename to #{suggestion}", "quickfix", text_edits, uri)

          [code_action | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  @spec text_edits(SourceFile.t(), non_neg_integer(), atom(), String.t(), atom()) ::
          {:ok, [TextEdit.t()]} | :error
  defp text_edits(%SourceFile{} = source_file, line, module, name, suggestion) do
    with {:ok, updated_text} <- apply_transform(source_file, line, module, name, suggestion) do
      to_text_edits(source_file.text, updated_text)
    end
  end

  defp apply_transform(source_file, line, module, name, suggestion) do
    with {:ok, ast, comments} <- Ast.from(source_file) do
      function_atom = String.to_atom(name)

      one_based_line = line + 1

      updated_text =
        ast
        |> Macro.postwalk(fn
          {:., [line: ^one_based_line],
           [{:__aliases__, module_meta, module_alias}, ^function_atom]} ->
            case expand_alias(source_file, module_alias, line) do
              {:ok, ^module} ->
                {:., [line: one_based_line],
                 [{:__aliases__, module_meta, module_alias}, suggestion]}

              _ ->
                {:., [line: one_based_line],
                 [{:__aliases__, module_meta, module_alias}, function_atom]}
            end

          # erlang call
          {:., [line: ^one_based_line], [{:__block__, module_meta, [^module]}, ^function_atom]} ->
            {:., [line: one_based_line], [{:__block__, module_meta, [module]}, suggestion]}

          other ->
            other
        end)
        |> Ast.to_string(comments)

      {:ok, updated_text}
    end
  end

  @spec expand_alias(SourceFile.t(), [atom()], non_neg_integer()) :: {:ok, atom()} | :error
  defp expand_alias(source_file, module_alias, line) do
    with {:ok, aliases} <- aliases_at(source_file, line) do
      aliases
      |> Enum.map(fn {module, aliased} ->
        module = module |> module_to_alias() |> List.first()
        aliased = module_to_alias(aliased)

        {module, aliased}
      end)
      |> Enum.find(fn {module, _aliased} -> List.starts_with?(module_alias, [module]) end)
      |> case do
        {_module, aliased} ->
          module_alias = aliased ++ Enum.drop(module_alias, 1)

          {:ok, Module.concat(module_alias)}

        nil ->
          {:ok, Module.concat(module_alias)}
      end
    end
  end

  defp aliases_at(source_file, line) do
    one_based_line = line + 1

    metadata = Parser.parse_string(source_file.text, true, true, {one_based_line, 1})

    case metadata.lines_to_env[one_based_line] do
      %ElixirSense.Core.State.Env{aliases: aliases} -> {:ok, aliases}
      _ -> :error
    end
  end

  defp module_to_alias(module) do
    module |> Module.split() |> Enum.map(&String.to_atom/1)
  end
end
