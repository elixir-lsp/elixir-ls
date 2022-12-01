file_generator = StreamData.string(:alphanumeric, min_size: 10, max_size: 120)

line_endings = ["\r", "\n", "\r\n"]

generate_lines = fn line_count ->
  :alphanumeric
  |> StreamData.string(min_size: 10, max_size: 120)
  |> Enum.take(line_count)
end

Benchee.run(
  %{
    ":array.get(count - 1, array)" => fn %{array: array, count: count} ->
      :array.get(count - 1, array)
    end,
    "Enum.at(lines, count - 1)" => fn %{lines: lines, count: count} ->
      Enum.at(lines, count - 1)
    end,
    "list |> List.to_tuple() |> elem(count - 1)" => fn %{lines: lines, count: count} ->
      lines |> List.to_tuple() |> elem(count - 1)
    end,
    "tuple" => fn %{tuple: tuple, count: count} ->
      elem(tuple, count - 1)
    end
  },
  inputs:
    Map.new([80, 500, 1500], fn count ->
      lines = generate_lines.(count)

      {"#{count} lines",
       %{
         lines: lines,
         array: :array.from_list(lines),
         tuple: List.to_tuple(lines),
         count: count
       }}
    end)
)
