defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes.AST do
  @moduledoc """
  AST manipulation helpers for the `ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes`\
  command.
  """

  @doc "Parses a string and converts the first function call, pre-order depth-first, into a pipe."
  def to_pipe(code_string) do
    {piped_ast, _} =
      code_string
      |> Code.string_to_quoted!()
      |> Macro.prewalk(%{has_piped: false}, &do_to_pipe/2)

    {:ok, ast_to_string(piped_ast)}
  rescue
    _ ->
      {:error, :invalid_code}
  end

  @doc "Parses a string and converts the first pipe call, post-order depth-first, into a function call."
  def from_pipe(code_string) do
    {unpiped_ast, _} =
      code_string
      |> Code.string_to_quoted!()
      |> Macro.postwalk(%{has_unpiped: false}, fn
        {:|>, line, [h, {{:., line, [{_, _, nil}]} = anonymous_function_node, line, t}]},
        %{has_unpiped: false} = acc ->
          {{anonymous_function_node, line, [h | t]}, Map.put(acc, :has_unpiped, true)}

        {:|>, line, [left, {function, _, args}]}, %{has_unpiped: false} = acc ->
          {{function, line, [left | args]}, Map.put(acc, :has_unpiped, true)}

        node, acc ->
          {node, acc}
      end)

    {:ok, ast_to_string(unpiped_ast)}
  rescue
    _ ->
      {:error, :invalid_code}
  end

  defp do_to_pipe({:|>, line, [left, right]}, %{has_piped: false} = acc) do
    {{:|>, line, [left |> do_to_pipe(acc) |> elem(0), right]}, Map.put(acc, :has_piped, true)}
  end

  defp do_to_pipe(
         {{:., line, [{_, _, nil}]} = anonymous_function_node, _meta, [h | t]},
         %{has_piped: false} = acc
       ) do
    {{:|>, line, [h, {anonymous_function_node, line, t}]}, Map.put(acc, :has_piped, true)}
  end

  defp do_to_pipe({{:., line, _args} = function, _meta, args}, %{has_piped: false} = acc)
       when args != [] do
    {{:|>, line, [hd(args), {function, line, tl(args)}]}, Map.put(acc, :has_piped, true)}
  end

  defp do_to_pipe({function, line, [h | t]} = node, %{has_piped: false} = acc)
       when is_atom(function) and function not in [:., :__aliases__, :"::", :{}, :|>] and t != [] do
    with :error <- Code.Identifier.binary_op(function),
         :error <- Code.Identifier.unary_op(function) do
      {{:|>, line, [h, {function, line, t}]}, Map.put(acc, :has_piped, true)}
    else
      _ ->
        {node, acc}
    end
  end

  defp do_to_pipe(node, acc) do
    {node, acc}
  end

  def ast_to_string(ast) do
    Macro.to_string(ast, fn node, rendered ->
      case sigil_call(node, fn _a, s -> s end) do
        {:ok, parsed_sigil} -> parsed_sigil
        _ -> rendered
      end
    end)
  end

  # TODO: remove this when only Elixir >= 1.13 is supported
  # The code below is copied from the Elixir source-code because a
  # fix which was introduced in
  # https://github.com/elixir-lang/elixir/commit/88d82f059756ed1eb56a562fae7092f77d941de8
  # is needed for proper treatment of sigils in our use-case.
  defp sigil_call({sigil, meta, [{:<<>>, _, _} = parts, args]} = ast, fun)
       when is_atom(sigil) and is_list(args) do
    delimiter = Keyword.get(meta, :delimiter, "\"")
    {left, right} = delimiter_pair(delimiter)

    case Atom.to_string(sigil) do
      <<"sigil_", name>> when name >= ?A and name <= ?Z ->
        args = sigil_args(args, fun)
        {:<<>>, _, [binary]} = parts
        formatted = <<?~, name, left::binary, binary::binary, right::binary, args::binary>>
        {:ok, fun.(ast, formatted)}

      <<"sigil_", name>> when name >= ?a and name <= ?z ->
        args = sigil_args(args, fun)
        formatted = "~" <> <<name>> <> interpolate(parts, left, right) <> args
        {:ok, fun.(ast, formatted)}

      _ ->
        :error
    end
  end

  defp sigil_call(_other, _fun) do
    :error
  end

  defp delimiter_pair("["), do: {"[", "]"}
  defp delimiter_pair("{"), do: {"{", "}"}
  defp delimiter_pair("("), do: {"(", ")"}
  defp delimiter_pair("<"), do: {"<", ">"}
  defp delimiter_pair("\"\"\""), do: {"\"\"\"\n", "\"\"\""}
  defp delimiter_pair("'''"), do: {"'''\n", "'''"}
  defp delimiter_pair(str), do: {str, str}

  defp sigil_args([], _fun), do: ""
  defp sigil_args(args, fun), do: fun.(args, List.to_string(args))

  defp interpolate({:<<>>, _, [parts]}, left, right) when left in [~s["""\n], ~s['''\n]] do
    <<left::binary, parts::binary, right::binary>>
  end

  defp interpolate({:<<>>, _, parts}, left, right) do
    parts =
      Enum.map_join(parts, "", fn
        {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [arg]}, {:binary, _, _}]} ->
          "\#{" <> ast_to_string(arg) <> "}"

        binary when is_binary(binary) ->
          escape_sigil(binary, left)
      end)

    <<left::binary, parts::binary, right::binary>>
  end

  defp escape_sigil(parts, "("), do: String.replace(parts, ")", ~S"\)")
  defp escape_sigil(parts, "{"), do: String.replace(parts, "}", ~S"\}")
  defp escape_sigil(parts, "["), do: String.replace(parts, "]", ~S"\]")
  defp escape_sigil(parts, "<"), do: String.replace(parts, ">", ~S"\>")
  defp escape_sigil(parts, delimiter), do: String.replace(parts, delimiter, "\\#{delimiter}")
end
