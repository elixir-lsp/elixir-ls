defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Indentation do
  @moduledoc """
  Code folding based on indentation only.
  """

  @doc """
  """
  def provide_ranges(text) do
    cells = find_cells(text)
    ranges = pair_cells(cells)
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

  def pair_cells(cells) do
    do_pair_cells(cells, [], [], [])
  end

  # Base case
  defp do_pair_cells([], _, _, pairs) do
    pairs
    |> Enum.map(fn
      {cell1, cell2, []} ->
        {cell1, cell2}

      {cell1, _, empties} ->
        [{first_empty_row, _} | _] = empties |> Enum.reverse()
        {cell1, {first_empty_row - 1, nil}}
    end)
    |> Enum.reject(fn {{r1, _}, {r2, _}} -> r1 + 1 >= r2 end)
    |> Enum.sort()
  end

  # Empty stack with empty row
  defp do_pair_cells([{_, nil} = cell | tail], [], empties, pairs) do
    do_pair_cells(tail, [], [cell | empties], pairs)
  end

  # Empty stack
  defp do_pair_cells([cell | tail], [], empties, pairs) do
    do_pair_cells(tail, [cell], empties, pairs)
  end

  # Non-empty stack
  defp do_pair_cells(
         [{_, col_cur} = cur | tail_cells],
         [{_, col_top} = top | tail_stack] = stack,
         empties,
         pairs
       ) do
    {new_stack, new_empties, new_pairs} =
      cond do
        is_nil(col_cur) ->
          {stack, [cur | empties], pairs}

        col_cur > col_top ->
          {[cur | stack], [], pairs}

        col_cur == col_top ->
          {[cur | tail_stack], [], [{top, cur, empties} | pairs]}

        col_cur < col_top ->
          {leftovers, new_tail_stack} = stack |> Enum.split_while(fn {_, c} -> col_cur <= c end)
          new_pairs = leftovers |> Enum.map(&{&1, cur, empties})
          {new_tail_stack, [], new_pairs ++ pairs}
      end

    do_pair_cells(tail_cells, new_stack, new_empties, new_pairs)
  end
end
