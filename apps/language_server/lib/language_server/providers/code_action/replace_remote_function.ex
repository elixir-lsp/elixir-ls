defmodule ElixirLS.LanguageServer.Providers.CodeAction.ReplaceRemoteFunction do
  @moduledoc """
  Code actions that replace unknown remote function with functions from the same module that have
  similar names
  """

  use ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.Providers.CodeAction.CodeActionResult
  alias ElixirLS.LanguageServer.Providers.CodeMod.Ast
  alias ElixirLS.LanguageServer.Providers.CodeMod.Diff
  alias ElixirLS.LanguageServer.Providers.CodeMod.Text
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Metadata

  import ElixirLS.LanguageServer.Providers.CodeAction.Helpers

  @spec apply(SourceFile.t(), String.t(), [map()]) :: [CodeActionResult.t()]
  def apply(%SourceFile{} = source_file, uri, diagnostics) do
    Enum.flat_map(diagnostics, fn diagnostic ->
      with {:ok, module, function, arity, line_number} <- extract_function_and_line(diagnostic),
           {:ok, suggestions} <- prepare_suggestions(module, function, arity) do
        to_code_actions(source_file, line_number, module, function, suggestions, uri)
      else
        _ -> []
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
    suggestions =
      for {module_function, ^arity} <- module_functions(module),
          distance = module_function |> Atom.to_string() |> String.jaro_distance(function),
          distance >= @function_threshold do
        {distance, module_function}
      end
      |> Enum.sort(:desc)
      |> Enum.take(@max_suggestions)
      |> Enum.map(fn {_distance, module_function} -> module_function end)

    {:ok, suggestions}
  end

  defp module_functions(module) do
    if function_exported?(module, :__info__, 1) do
      module.__info__(:functions)
    else
      module.module_info(:functions)
    end
  end

  defp to_code_actions(%SourceFile{} = source_file, line_number, module, name, suggestions, uri) do
    suggestions
    |> Enum.reduce([], fn suggestion, acc ->
      case apply_transform(source_file, line_number, module, name, suggestion) do
        {:ok, [_ | _] = text_edits} ->
          text_edits = Enum.map(text_edits, &update_line(&1, line_number))

          code_action =
            CodeActionResult.new("Rename to #{suggestion}", "quickfix", text_edits, uri)

          [code_action | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp apply_transform(source_file, line_number, module, name, suggestion) do
    with {:ok, text} <- fetch_line(source_file, line_number),
         {:ok, ast} <- Ast.from(text) do
      function_atom = String.to_atom(name)

      leading_indent = Text.leading_indent(text)
      trailing_comment = Text.trailing_comment(text)

      ast
      |> Macro.postwalk(fn
        {:., function_meta, [{:__aliases__, module_meta, module_alias}, ^function_atom]} ->
          case expand_alias(source_file, module_alias, line_number) do
            {:ok, ^module} ->
              {:., function_meta, [{:__aliases__, module_meta, module_alias}, suggestion]}

            _ ->
              {:., function_meta, [{:__aliases__, module_meta, module_alias}, function_atom]}
          end

        # erlang call
        {:., function_meta, [^module, ^function_atom]} ->
          {:., function_meta, [module, suggestion]}

        other ->
          other
      end)
      |> to_one_line_string()
      |> case do
        {:ok, updated_text} ->
          text_edits = Diff.diff(text, "#{leading_indent}#{updated_text}#{trailing_comment}")

          {:ok, text_edits}

        :error ->
          :error
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

  @spec expand_alias(SourceFile.t(), [atom()], non_neg_integer()) :: {:ok, atom()} | :error
  defp expand_alias(source_file, module_alias, line_number) do
    # TODO use Macro.Env
    with {:ok, aliases} <- aliases_at(source_file, line_number) do
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

  defp aliases_at(source_file, line_number) do
    one_based_line = line_number + 1

    metadata = Parser.parse_string(source_file.text, true, false, {one_based_line, 1})
    env = Metadata.get_cursor_env(metadata, {one_based_line, 1})
    {:ok, env.aliases}
  end

  defp module_to_alias(module) do
    module |> Module.split() |> Enum.map(&String.to_atom/1)
  end
end
