alias ElixirLS.LanguageServer.Experimental.SourceFile.Document
file_generator = StreamData.string(:alphanumeric, min_size: 10, max_size: 120)

line_endings = ["\r", "\n", "\r\n"]

generate_lines = fn line_count ->
  :alphanumeric
  |> StreamData.string(min_size: 10, max_size: 120)
  |> Enum.take(line_count)
end

Benchee.run(
  %{
    "String.split |> Enum.at" => fn %{text: text, count: count} ->
      text
      |> String.split(line_endings)
      |> Enum.at(count - 1)
    end,
    "Enum.at" => fn %{lines: lines, count: count} ->
      Enum.at(lines, count - 1)
    end,
    "Document" => fn %{document: doc, count: count} ->
      {:ok, _} = Document.fetch_line(doc, count - 1)
    end,
    "Document.new |> Document.fetch_line" => fn %{text: text, count: count} ->
      text
      |> Document.new()
      |> Document.fetch_line(count)
    end
  },
  inputs:
    Map.new([80, 500, 1500], fn count ->
      lines = generate_lines.(count)
      text = Enum.join(lines, Enum.random(line_endings))

      {"#{count} lines",
       %{
         lines: lines,
         document: Document.new(text),
         text: text,
         count: count
       }}
    end)
)
