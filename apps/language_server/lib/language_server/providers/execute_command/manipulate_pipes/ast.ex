defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes.AST do
  @moduledoc """
  AST manipulation helpers for the `ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes`\
  command.
  """

  # We replace newlines with \n because Code.string_to_quoted!()
  # doesn't work when the line separator is purely \r
  @newlines ["\n", "\r", "\r\n"]

  @doc "Parses a string and converts the first function call, pre-order depth-first, into a pipe."
  def to_pipe(code_string) do
    {piped_ast, _} =
      code_string
      |> String.replace(@newlines, "\n")
      |> Code.string_to_quoted!()
      |> Macro.prewalk(%{has_piped: false}, &do_to_pipe/2)

    Macro.to_string(piped_ast)
  end

  @doc "Parses a string and converts the first pipe call, post-order depth-first, into a function call."
  def from_pipe(code_string) do
    {unpiped_ast, _} =
      code_string
      |> String.replace(@newlines, "\n")
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

    Macro.to_string(unpiped_ast)
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
end
