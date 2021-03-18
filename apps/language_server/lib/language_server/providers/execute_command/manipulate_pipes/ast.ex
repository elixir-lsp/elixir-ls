defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes.AST do
  @moduledoc """
  AST manipulation helpers for the `ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes`\
  command.
  """

  @doc "Parses an AST and converts the first function call, depth-first, into a pipe."
  def to_pipe(code) do
    {piped_ast, _} = Macro.prewalk(code, %{has_piped: false}, &to_pipe/2)
    piped_ast
  end

  defp to_pipe({:|>, line, [left, right]}, %{has_piped: false} = acc) do
    {{:|>, line, [left |> to_pipe(acc) |> elem(0), right]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe(
         {{:., line, [{_, _, nil}]} = anonymous_function_node, _meta, [h | t]},
         %{has_piped: false} = acc
       ) do
    {{:|>, line, [h, {anonymous_function_node, line, t}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe({{:., line, _args} = function, _meta, args}, %{has_piped: false} = acc)
       when args != [] do
    {{:|>, line, [hd(args), {function, line, tl(args)}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe({function, line, [h | t]}, %{has_piped: false} = acc)
       when is_atom(function) and t != [] do
    {{:|>, line, [h, {function, line, t}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe(node, acc) do
    {node, acc}
  end
end
