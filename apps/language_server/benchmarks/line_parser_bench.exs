alias ElixirLS.LanguageServer.SourceFile
alias ElixirLS.LanguageServer.Experimental.SourceFile.LineParser
file_generator = StreamData.string(:alphanumeric, min_size: 10, max_size: 120)

line_endings = ["\r", "\n", "\r\n"]

generate_file = fn line_count ->
  :alphanumeric
  |> StreamData.string(min_size: 10, max_size: 120)
  |> Enum.take(line_count)
  |> Enum.join(Enum.random(line_endings))
end

large_file = generate_file.(500)

Benchee.run(
  %{
    "SourceFile.lines" => &SourceFile.lines/1,
    "SourceFile.lines_with_endings/1" => &SourceFile.lines_with_endings/1,
    "LineParser.parse" => &LineParser.parse(&1, 1)
  },
  inputs: %{
    "80 lines" => generate_file.(80),
    "500 lines" => generate_file.(500),
    "1500 lines" => generate_file.(1500)
  }
)
