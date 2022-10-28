defmodule ElixirLS.LanguageServer.Experimental.SourceFile.Conversions do
  @moduledoc """
  Functions to convert between language server representations and elixir-native representations.

  The LSP protocol defines positions in terms of their utf-16 representation (thanks, windows),
  so when a document change comes in, we need to recalculate the positions of the change if
  the line contains non-ascii characters. If it's a pure ascii line, then the positions
  are the same in both utf-8 and utf-16, since they reference characters and not bytes.
  """
  alias ElixirLS.LanguageServer.Experimental.CodeUnit
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Line
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Document
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Range, as: ElixirRange
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Position, as: ElixirPosition
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Position, as: LSPosition
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range, as: LSRange
  alias ElixirLS.LanguageServer.Protocol

  import Line
  import Protocol, only: [range: 4]

  @elixir_ls_index_base 1

  def ensure_uri("file://" <> _ = uri), do: uri

  def ensure_uri(path),
    do: ElixirLS.LanguageServer.SourceFile.Path.to_uri(path)

  def ensure_path("file://" <> _ = uri),
    do: ElixirLS.LanguageServer.SourceFile.Path.from_uri(uri)

  def ensure_path(path), do: path

  def to_elixir(
        %LSRange{} = ls_range,
        %SourceFile{} = source
      ) do
    with {:ok, start_pos} <- to_elixir(ls_range.start, source.document),
         {:ok, end_pos} <- to_elixir(ls_range.end, source.document) do
      {:ok, %ElixirRange{start: start_pos, end: end_pos}}
    end
  end

  def to_elixir(range(start_line, start_char, end_line, end_char), %SourceFile{} = source) do
    ls_range = %LSRange{
      start: %LSPosition{line: start_line, character: start_char},
      end: %LSPosition{line: end_line, character: end_char}
    }

    to_elixir(ls_range, source)
  end

  def to_elixir(%LSPosition{} = position, %SourceFile{} = source_file) do
    to_elixir(position, source_file.document)
  end

  def to_elixir(%ElixirPosition{} = position, _) do
    position
  end

  def to_elixir(%LSPosition{} = position, %Document{} = document) do
    document_size = Document.size(document)
    # we need to handle out of bounds line numbers, because it's possible to build a document
    # by starting with an empty document and appending to the beginning of it, with a start range of
    # {0, 0} and and end range of {1, 0} (replace the first line)
    document_line_number = min(position.line, document_size)
    elixir_line_number = document_line_number + @elixir_ls_index_base
    ls_character = position.character

    cond do
      document_line_number == document_size and ls_character == 0 ->
        # allow a line one more than the document size, as long as the character is 0.
        # that means we're operating on the last line of the document

        {:ok, ElixirPosition.new(elixir_line_number, ls_character)}

      position.line >= document_size ->
        # they've specified something outside of the document clamp it down so they can append at the
        # end
        {:ok, ElixirPosition.new(elixir_line_number, 0)}

      true ->
        with {:ok, line} <- Document.fetch_line(document, elixir_line_number) do
          elixir_character =
            case line do
              line(ascii?: true, text: text) ->
                min(ls_character, byte_size(text))

              line(text: text) ->
                {:ok, utf16_text} = to_utf16(text)
                lsp_character_to_elixir(utf16_text, ls_character)
            end

          {:ok, ElixirPosition.new(elixir_line_number, elixir_character)}
        end
    end
  end

  def to_elixir(%{range: %{start: start_pos, end: end_pos}}, _source_file) do
    # this is actually an elixir sense range... note that it's a bare map with
    # column keys rather than character keys.
    %{line: start_line, column: start_col} = start_pos
    %{line: end_line, column: end_col} = end_pos

    range = %ElixirRange{
      start: ElixirPosition.new(start_line, start_col - 1),
      end: ElixirPosition.new(end_line, end_col - 1)
    }

    {:ok, range}
  end

  def to_lsp(%ElixirRange{} = ex_range, %SourceFile{} = source) do
    with {:ok, start_pos} <- to_lsp(ex_range.start, source.document),
         {:ok, end_pos} <- to_lsp(ex_range.end, source.document) do
      {:ok, %LSRange{start: start_pos, end: end_pos}}
    end
  end

  def to_lsp(%ElixirPosition{} = position, %SourceFile{} = source_file) do
    to_lsp(position, source_file.document)
  end

  def to_lsp(%ElixirPosition{} = position, %Document{} = document) do
    %ElixirPosition{character: elixir_character, line: elixir_line} = position

    with {:ok, line} <- Document.fetch_line(document, elixir_line) do
      lsp_character =
        case line do
          line(ascii?: true, text: text) ->
            min(position.character, byte_size(text))

          line(text: utf8_text) ->
            {:ok, character} = elixir_character_to_lsp(utf8_text, elixir_character)
            character
        end

      ls_pos = LSPosition.new(character: lsp_character, line: elixir_line - @elixir_ls_index_base)
      {:ok, ls_pos}
    end
  end

  def to_lsp(%LSPosition{} = position, _) do
    {:ok, position}
  end

  # Private

  defp extract_lsp_character(%ElixirPosition{} = position, line(ascii?: true)) do
    {:ok, position.character}
  end

  defp extract_lsp_character(%ElixirPosition{} = position, line(text: utf8_text)) do
    {:ok, CodeUnit.utf16_offset(utf8_text, position.character)}
  end

  defp extract_elixir_character(%LSPosition{} = position, line(ascii?: true)) do
    {:ok, position.character}
  end

  defp extract_elixir_character(%LSPosition{} = position, line(text: utf8_text)) do
    {:ok, CodeUnit.utf8_offset(utf8_text, position.character)}
  end
end
