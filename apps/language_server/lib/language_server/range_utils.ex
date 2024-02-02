defmodule ElixirLS.LanguageServer.RangeUtils do
  @moduledoc """
  Utilities for working with ranges.
  """

  import ElixirLS.LanguageServer.Protocol

  @type range_t :: map

  def valid?(range(start_line, start_character, end_line, end_character))
      when is_integer(start_line) and is_integer(end_line) and is_integer(start_character) and
             is_integer(end_character) do
    (start_line >= 0 and end_line >= 0 and start_character >= 0 and end_character >= 0 and
       start_line < end_line) or (start_line == end_line and start_character <= end_character)
  end

  def valid?(_), do: false

  def increasingly_narrowing?([left]), do: valid?(left)

  def increasingly_narrowing?([left, right | rest]) do
    valid?(left) and valid?(right) and left_in_right?(right, left) and
      increasingly_narrowing?([right | rest])
  end

  @spec left_in_right?(range_t, range_t) :: boolean
  def left_in_right?(
        range(start_line_1, start_character_1, end_line_1, end_character_1),
        range(start_line_2, start_character_2, end_line_2, end_character_2)
      ) do
    (start_line_1 > start_line_2 or
       (start_line_1 == start_line_2 and start_character_1 >= start_character_2)) and
      (end_line_1 < end_line_2 or
         (end_line_1 == end_line_2 and end_character_1 <= end_character_2))
  end

  def sort_ranges_widest_to_narrowest(ranges) do
    ranges
    |> Enum.sort_by(fn range(start_line, start_character, end_line, end_character) ->
      {start_line - end_line, start_character - end_character}
    end)
  end

  def union(
        range(start_line_1, start_character_1, end_line_1, end_character_1) = left,
        range(start_line_2, start_character_2, end_line_2, end_character_2) = right
      ) do
    _intersection = intersection(left, right)

    {start_line, start_character} =
      cond do
        start_line_1 < start_line_2 -> {start_line_1, start_character_1}
        start_line_1 > start_line_2 -> {start_line_2, start_character_2}
        true -> {start_line_1, min(start_character_1, start_character_2)}
      end

    {end_line, end_character} =
      cond do
        end_line_1 < end_line_2 -> {end_line_2, end_character_2}
        end_line_1 > end_line_2 -> {end_line_1, end_character_1}
        true -> {end_line_1, max(end_character_1, end_character_2)}
      end

    range(start_line, start_character, end_line, end_character)
  end

  def intersection(
        range(start_line_1, start_character_1, end_line_1, end_character_1),
        range(start_line_2, start_character_2, end_line_2, end_character_2)
      ) do
    {start_line, start_character} =
      cond do
        start_line_1 < start_line_2 -> {start_line_2, start_character_2}
        start_line_1 > start_line_2 -> {start_line_1, start_character_1}
        true -> {start_line_1, max(start_character_1, start_character_2)}
      end

    {end_line, end_character} =
      cond do
        end_line_1 < end_line_2 -> {end_line_1, end_character_1}
        end_line_1 > end_line_2 -> {end_line_2, end_character_2}
        true -> {end_line_1, min(end_character_1, end_character_2)}
      end

    result = range(start_line, start_character, end_line, end_character)

    if not valid?(result) do
      raise ArgumentError, message: "no intersection"
    end

    result
  end

  def merge_ranges_lists(ranges_1, ranges_2) do
    if hd(ranges_1) != hd(ranges_2) do
      raise ArgumentError, message: "range list do not start with the same range"
    end

    if not increasingly_narrowing?(ranges_1) do
      raise ArgumentError, message: "ranges_1 is not increasingly narrowing"
    end

    if not increasingly_narrowing?(ranges_2) do
      raise ArgumentError, message: "ranges_2 is not increasingly narrowing"
    end

    do_merge_ranges(ranges_1, ranges_2, [])
    |> Enum.reverse()
  end

  defp do_merge_ranges([], [], acc) do
    acc
  end

  defp do_merge_ranges([range_1 | rest_1], [], acc) do
    # range_1 is guaranteed to be increasingly narrowing
    do_merge_ranges(rest_1, [], [range_1 | acc])
  end

  defp do_merge_ranges([], [range_2 | rest_2], acc) do
    # we might have added a narrower range by favoring range_1 in the previous iteration
    range_2 = trim_range_to_acc(range_2, acc)

    do_merge_ranges([], rest_2, [range_2 | acc])
  end

  defp do_merge_ranges([range | rest_1], [range | rest_2], acc) do
    do_merge_ranges(rest_1, rest_2, [range | acc])
  end

  defp do_merge_ranges([range_1 | rest_1], [range_2 | rest_2], acc) do
    # we might have added a narrower range by favoring range_1 in the previous iteration
    range_2 = trim_range_to_acc(range_2, acc)

    cond do
      left_in_right?(range_2, range_1) ->
        # range_2 in range_1
        do_merge_ranges(rest_1, [range_2 | rest_2], [range_1 | acc])

      left_in_right?(range_1, range_2) ->
        # range_1 in range_2
        do_merge_ranges([range_1 | rest_1], rest_2, [range_2 | acc])

      true ->
        # ranges intersect - add union and favor range_1
        union_range = union(range_1, range_2)
        do_merge_ranges(rest_1, rest_2, [range_1, union_range | acc])
    end
  end

  defp trim_range_to_acc(range, []), do: range

  defp trim_range_to_acc(range, [acc_range | _]) do
    intersection(range, acc_range)
  end
end
