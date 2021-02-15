defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Indentation do
  @moduledoc """
  Code folding based on indentation only.
  """

  @doc """
  Provides ranges for the source text based on the indentation level.
  Note that we trim trailing empy rows from regions.
  """
  def provide_ranges(text) do
    ranges =
      text
      |> find_cells()
      |> pair_cells()
      |> pairs_to_ranges()

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
        [first_empty_cell | _] = empties |> Enum.reverse()
        {cell1, first_empty_cell}
    end)
    |> Enum.reject(fn {{r1, _}, {r2, _}} -> r1 + 1 >= r2 end)
    |> Enum.sort()
  end

  # Empty row
  defp do_pair_cells([{_, nil} = head | tail], stack, empties, pairs) do
    do_pair_cells(tail, stack, [head | empties], pairs)
  end

  # Empty stack
  defp do_pair_cells([head | tail], [], empties, pairs) do
    do_pair_cells(tail, [head], empties, pairs)
  end

  # Non-empty stack: head is to the right of the top of the stack
  defp do_pair_cells([{_, x} = head | tail], [{_, y} | _] = stack, _, pairs) when x > y do
    do_pair_cells(tail, [head | stack], [], pairs)
  end

  # Non-empty stack: head is equal to or to the left of the top of the stack
  defp do_pair_cells([{_, x} = head | tail], stack, empties, pairs) do
    # If the head is <= to the top of the stack, then we need to pair it with
    # everything on the stack to the right of it.
    # The head can also start a new region, so it's pushed onto the stack.
    {leftovers, new_tail_stack} = stack |> Enum.split_while(fn {_, y} -> x <= y end)
    new_pairs = leftovers |> Enum.map(&{&1, head, empties})
    do_pair_cells(tail, [head | new_tail_stack], [], new_pairs ++ pairs)
  end

  defp pairs_to_ranges(pairs) do
    pairs
    |> Enum.map(fn
      {{r1, _}, {r2, _}} -> %{"startLine" => r1, "endLine" => r2 - 1, "kind?" => "region"}
    end)
  end
end
