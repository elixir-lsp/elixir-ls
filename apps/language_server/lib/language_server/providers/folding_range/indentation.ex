defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Indentation do
  @moduledoc """
  Code folding based on indentation only.
  """

  @doc """
  """
  def provide_ranges(text) do
    cells = find_cells(text) |> IO.inspect(label: :cells)
    ranges = pair_cells(cells, [], [])
    ranges_2 = pair_cells_2(cells)
    ranges_2 |> IO.inspect(label: :ranges_2)
    {:ok, ranges}
  end

  # If we think of the code text as a grid, this function finds the cells whose
  # columns are the start of each row (line).
  # Empty rows are represented as {row, nil}.
  @spec find_cells(String.t()) :: [{non_neg_integer(), non_neg_integer()}]
  defp find_cells(text) do
    text
    |> String.trim()
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.map(fn {line, row} ->
      full = line |> String.length()
      trimmed = line |> String.trim_leading() |> String.length()
      col = if {full, trimmed} == {0, 0}, do: nil, else: full - trimmed
      {row, col}
    end)
  end

  defp pair_cells([], _, pairs), do: pairs

  defp pair_cells([cell | rest], [], pairs) do
    pair_cells(rest, [cell], pairs)
  end

  defp pair_cells(
         [{row_cur, col_cur} = cur | rest],
         [{_, col_top} = top | tail_stack] = stack,
         pairs
       ) do
    # cur |> IO.inspect(label: :current)
    # top |> IO.inspect(label: :top_stack)
    # tail_stack |> IO.inspect(label: :tail_stack)
    # pairs |> IO.inspect(label: :pairs)
    # "" |> IO.puts()

    {new_stack, new_pairs} =
      cond do
        is_nil(col_cur) ->
          case stack do
            [right | [left | new_tail_stack]] ->
              {new_tail_stack, [{left, right} | pairs]}

            _ ->
              {tail_stack, pairs}
          end

        col_cur > col_top ->
          {[cur | stack], pairs}

        col_cur == col_top ->
          {tail_stack, [{top, {row_cur - 1, col_cur}} | pairs]}

        col_cur < col_top ->
          case tail_stack do
            [match | new_tail_stack] ->
              {new_tail_stack, [{match, {row_cur - 1, col_cur}} | pairs]}

            _ ->
              {tail_stack, pairs}
          end
      end

    pair_cells(rest, new_stack, new_pairs)
  end

  def pair_cells_2(cells) do
    do_pair_cells_2(cells, [], [], [])
  end

  defp do_pair_cells_2([], _, _, pairs) do
    pairs
    |> Enum.map(fn
      {cell1, cell2, []} ->
        {cell1, cell2}

      {cell1, _, empties} ->
        [{first_empty_row, _} | _] = empties |> Enum.reverse()
        {cell1, {first_empty_row - 1, nil}}
    end)
    |> Enum.reject(fn {{r1, _}, {r2, _}} -> r2 <= r1 + 1 end)
    |> Enum.sort()
  end

  defp do_pair_cells_2([{_, col} = cell | tail], [], empties, pairs) do
    {new_stack, new_empties} =
      if is_nil(col) do
        {[], [cell | empties]}
      else
        {[cell], empties}
      end

    do_pair_cells_2(tail, new_stack, new_empties, pairs)
  end

  defp do_pair_cells_2(
         [{_, col_cur} = cur | tail_cells],
         [{_, col_top} = top | tail_stack] = stack,
         empties,
         pairs
       ) do
    cur |> IO.inspect(label: :cur)
    stack |> IO.inspect(label: :stack)
    empties |> IO.inspect(label: :empties)
    pairs |> IO.inspect(label: :pairs)

    {new_stack, new_empties, new_pairs} =
      cond do
        is_nil(col_cur) ->
          "is_nil" |> IO.inspect(label: :clause)
          {stack, [cur | empties], pairs}

        col_cur > col_top ->
          ">" |> IO.inspect(label: :clause)
          {[cur | stack], [], pairs}

        col_cur == col_top ->
          "==" |> IO.inspect(label: :clause)
          {[cur | tail_stack], [], [{top, cur, empties} | pairs]}

        col_cur < col_top ->
          "<" |> IO.inspect(label: :clause)
          gr? = fn {_, c} -> col_cur <= c end
          {leftovers, new_tail_stack} = stack |> Enum.split_while(gr?)
          stack |> Enum.split_while(gr?) |> IO.inspect(label: :lists)
          leftovers |> IO.inspect()
          new_tail_stack |> IO.inspect(label: :new_tail_stack)
          new_pairs = leftovers |> Enum.map(&{&1, cur, empties})
          {new_tail_stack, [], new_pairs ++ pairs}
      end

    "" |> IO.puts()
    do_pair_cells_2(tail_cells, new_stack, new_empties, new_pairs)
  end

  # defp pair_cells_nsq([], pairs) do
  #   pairs
  #   |> IO.inspect()
  #   |> Enum.reduce([], fn {{_r1, c1}, {_r2, c2}} = pair, pairs ->
  #     if c1 > c2 do
  #       pairs
  #     else
  #       [pair | pairs]
  #     end
  #   end)
  # end

  # defp pair_cells_nsq([{_, nil} | tail], pairs) do
  #   pair_cells_nsq(tail, pairs)
  # end

  # defp pair_cells_nsq([{_, ch} = head | tail], pairs) do
  #   first_leq = Enum.find(tail, fn {_, ct} -> ct <= ch end)
  #   # head |> IO.inspect(label: :head)
  #   # first_leq |> IO.inspect(label: :first_leq)
  #   # pairs |> IO.inspect(label: :pairs)
  #   # "" |> IO.puts()

  #   new_pairs =
  #     case first_leq do
  #       nil -> pairs
  #       first_leq -> [{head, first_leq} | pairs]
  #     end

  #   pair_cells_nsq(tail, new_pairs)
  # end

  # defp collapse_nil(pairs, cells) do
  #   search = cells |> Enum.reverse()

  #   pairs
  #   |> Enum.map(fn {cell1, {r2, _}} ->
  #     cell2 = Enum.find(search, fn {r, c} -> r <= r2 and !is_nil(c) end)
  #     {cell1, cell2}
  #   end)
  # end
end
