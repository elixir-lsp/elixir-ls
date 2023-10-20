defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExtractFunction.CodeModExtractFunction do
  @moduledoc """
  Elixir refactoring functions.
  """

  alias VendoredSourceror.Zipper, as: Z

  @doc """
  Return zipper containing AST with extracted function.
  """
  def extract_function(zipper, start_line, end_line, function_name)
      when is_binary(function_name) do
    extract_function(zipper, start_line, end_line, String.to_atom(function_name))
  end

  def extract_function(%Z{} = zipper, start_line, end_line, function_name)
      when is_integer(start_line) and is_integer(end_line) and is_atom(function_name) do
    {quoted_after_extract, acc} = extract_lines(zipper, start_line, end_line, function_name)

    if Enum.empty?(acc.lines) do
      {:error, :not_extractable}
    else
      new_function_zipper = new_function(function_name, [], acc.lines) |> Z.zip()
      declared_vars = vars_declared(new_function_zipper) |> Enum.uniq()
      used_vars = vars_used(new_function_zipper) |> Enum.uniq()

      args = used_vars -- declared_vars
      returns = declared_vars |> Enum.filter(&(&1 in acc.vars))

      {zipper, extracted} =
        add_returned_vars(Z.zip(quoted_after_extract), returns, function_name, args, acc.lines)

      enclosing = acc.def

      zipper
      |> top_find(fn
        {:def, _meta, [{^enclosing, _, _}, _]} -> true
        _ -> false
      end)
      |> Z.insert_right(extracted)
      |> fix_block()
      |> Z.root()
    end
  end

  @doc """
  Return zipper containing AST for lines in the range from-to.
  """
  def extract_lines(%Z{} = zipper, start_line, end_line, replace_with \\ nil) do
    remove_range(zipper, start_line, end_line, %{
      lines: [],
      def: nil,
      def_end: nil,
      vars: [],
      replace_with: replace_with
    })
  end

  defp next_remove_range(%Z{} = zipper, from, to, acc) do
    next = Z.next(zipper)

    if is_nil(next) || next.node == true do
      # return zipper with lines removed
      {
        Z.top(zipper).node,
        %{acc | lines: Enum.reverse(acc.lines), vars: Enum.reverse(acc.vars)}
      }
    else
      remove_range(next, from, to, acc)
    end
  end

  defp remove_range(%Z{node: {:def, meta, [{marker, _, _}, _]}} = zipper, from, to, acc) do
    acc =
      if meta[:line] < from do
        x = put_in(acc.def, marker)
        put_in(x.def_end, meta[:end][:line])
      else
        acc
      end

    next_remove_range(zipper, from, to, acc)
  end

  defp remove_range(%Z{node: {marker, meta, children}} = zipper, from, to, acc) do
    if meta[:line] < from || meta[:line] > to || marker == :__block__ do
      next_remove_range(
        zipper,
        from,
        to,
        if meta[:line] > to && meta[:line] < acc.def_end && is_atom(marker) && is_nil(children) do
          put_in(acc.vars, [marker | acc.vars] |> Enum.uniq())
        else
          acc
        end
      )
    else
      acc = put_in(acc.lines, [Z.node(zipper) | acc.lines])

      if is_nil(acc.replace_with) do
        zipper
        |> Z.remove()
        |> next_remove_range(from, to, acc)
      else
        function_name = acc.replace_with
        acc = put_in(acc.replace_with, nil)

        zipper
        |> Z.replace({function_name, [], []})
        |> next_remove_range(from, to, acc)
      end
    end
  end

  defp remove_range(%Z{} = zipper, from, to, acc) do
    next_remove_range(zipper, from, to, acc)
  end

  defp vars_declared(%Z{} = new_function_zipper) do
    vars_declared(new_function_zipper, %{vars: []})
  end

  defp vars_declared(nil, acc) do
    Enum.reverse(acc.vars)
  end

  defp vars_declared(%Z{node: {:=, _, [{var, _, nil}, _]}} = zipper, acc)
       when is_atom(var) do
    zipper
    |> Z.next()
    |> vars_declared(put_in(acc.vars, [var | acc.vars]))
  end

  defp vars_declared(%Z{} = zipper, acc) do
    zipper
    |> Z.next()
    |> vars_declared(acc)
  end

  defp vars_used(%Z{} = new_function_zipper) do
    vars_used(new_function_zipper, %{vars: []})
  end

  defp vars_used(nil, acc) do
    Enum.reverse(acc.vars)
  end

  defp vars_used(%Z{node: {marker, _meta, nil}} = zipper, acc)
       when is_atom(marker) do
    zipper
    |> Z.next()
    |> vars_used(put_in(acc.vars, [marker | acc.vars]))
  end

  defp vars_used(%Z{} = zipper, acc) do
    zipper
    |> Z.next()
    |> vars_used(acc)
  end

  defp add_returned_vars(%Z{} = zipper, _returns = [], function_name, args, lines) do
    args = var_ast(args)

    {
      replace_function_call(zipper, function_name, {function_name, [], args}),
      new_function(function_name, args, lines)
    }
  end

  defp add_returned_vars(%Z{} = zipper, returns, function_name, args, lines)
       when is_list(returns) do
    args = var_ast(args)
    returned_vars = returned(returns)

    {
      replace_function_call(
        zipper,
        function_name,
        {:=, [], [returned_vars, {function_name, [], args}]}
      ),
      new_function(function_name, args, Enum.concat(lines, [returned_vars]))
    }
  end

  defp var_ast(vars) when is_list(vars) do
    Enum.map(vars, &var_ast/1)
  end

  defp var_ast(var) when is_atom(var) do
    {var, [], nil}
  end

  defp returned([var]) when is_atom(var) do
    var_ast(var)
  end

  defp returned(vars) when is_list(vars) do
    returned = vars |> var_ast() |> List.to_tuple()
    {:__block__, [], [returned]}
  end

  defp replace_function_call(%Z{} = zipper, function_name, replace_with) do
    zipper
    |> top_find(fn
      {^function_name, [], []} -> true
      _ -> false
    end)
    |> Z.replace(replace_with)
  end

  defp new_function(function_name, args, lines) do
    {:def, [do: [], end: []],
     [
       {function_name, [], args},
       [
         {
           {:__block__, [], [:do]},
           {:__block__, [], lines}
         }
       ]
     ]}
  end

  defp fix_block(%Z{} = zipper) do
    zipper
    |> top_find(fn
      {:{}, [], _children} -> true
      _ -> false
    end)
    |> case do
      nil ->
        zipper

      %Z{node: {:{}, [], [block | defs]}, path: meta} ->
        %Z{
          node: {
            block,
            {:__block__, [], defs}
          },
          path: meta
        }
    end
  end

  defp top_find(zipper, function) do
    zipper
    |> Z.top()
    |> Z.find(function)
  end
end
