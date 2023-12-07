defmodule ElixirLS.LanguageServer.Test.ParserContextBuilder do
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Parser

  def from_path(path, cursor_position \\ nil, language_id \\ "elixir") do
    text = File.read!(path)

    source_file = %SourceFile{text: text, version: 1, language_id: language_id}

    %Parser.Context{
      source_file: source_file,
      path: path
    }
    |> Parser.do_parse(cursor_position)
  end

  def from_string(text, cursor_position \\ nil, language_id \\ "elixir") do
    source_file = %SourceFile{text: text, version: 1, language_id: language_id}

    %Parser.Context{
      source_file: source_file,
      path: "nofile"
    }
    |> Parser.do_parse(cursor_position)
  end
end
