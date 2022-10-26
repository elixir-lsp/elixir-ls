defmodule ElixirLS.LanguageServer.Experimental.SourceFile.Conversions do
  @moduledoc """
  Functions to convert between language server representations and elixir-native representations.

  The LSP protocol defines positions in terms of their utf-16 representation (thanks, windows),
  so when a document change comes in, we need to recalculate the positions of the change if
  the line contains non-ascii characters. If it's a pure ascii line, then the positions
  are the same in both utf-8 and utf-16, since they reference characters and not bytes.
  """
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

      position.line > document_size ->
        # they've specified something outside of the document clamp it down so they can append at the
        # end
        {:ok, ElixirPosition.new(elixir_line_number, 0)}

      true ->
        with {:ok, line} <- Document.fetch_line(document, elixir_line_number) do
          elixir_character =
            case line do
              line(ascii?: true) ->
                ls_character

              line(text: text) ->
                {:ok, utf16_text} = to_utf16(text)
                lsp_character_to_elixir(utf16_text, ls_character)
            end

          {:ok, ElixirPosition.new(elixir_line_number, elixir_character)}
        end
    end
  end

  def to_lsp(%ElixirRange{} = ex_range, %SourceFile{} = source) do
    with {:ok, start_pos} <- to_lsp(ex_range.start, source.document),
         {:ok, end_pos} <- to_lsp(ex_range.end, source.document) do
      {:ok, %LSRange{start: start_pos, end: end_pos}}
    end
  end

  def to_lsp(%ElixirPosition{} = position, %Document{} = document) do
    %ElixirPosition{character: elixir_character, line: elixir_line} = position

    with {:ok, line} <- Document.fetch_line(document, elixir_line) do
      lsp_character =
        case line do
          line(ascii?: true) ->
            position.character

          line(text: utf8_text) ->
            elixir_character_to_lsp(utf8_text, elixir_character)
        end

      ls_pos = LSPosition.new(character: lsp_character, line: elixir_line - @elixir_ls_index_base)
      {:ok, ls_pos}
    end
  end

  def to_lsp(%LSPosition{} = position, _) do
    position
  end

  defp lsp_character_to_elixir(utf16_line, lsp_character) do
    # In LSP, the word "character" is a misnomer. What's being counted is a code unit.
    # in utf16, a code unit is two bytes long, while in utf8 it is one byte long.
    # This function converts from utf16 code units to utf8 code units. The code units
    # can then be used to do a simple byte-level operation on elixir binaries.
    # For ascii text, the code unit will mirror the number of bytes, but if there's any
    # unicode characters, it will vary from the byte count.
    byte_size = byte_size(utf16_line)

    # if character index is over the length of the string assume we pad it with spaces (1 byte in utf8)

    diff = div(max(lsp_character * 2 - byte_size, 0), 2)

    utf8_character =
      utf16_line
      |> binary_part(0, min(lsp_character * 2, byte_size))
      |> to_utf8()
      |> byte_size()
  end

  defp lsp_character_to_elixir_old(utf16_line, lsp_character) do
    byte_size = byte_size(utf16_line)

    # if character index is over the length of the string assume we pad it with spaces (1 byte in utf8)

    diff = div(max(lsp_character * 2 - byte_size, 0), 2)

    utf8_character =
      utf16_line
      |> binary_part(0, min(lsp_character * 2, byte_size))
      |> to_utf8()
      |> String.length()

    utf8_character + 1 + diff
  end

  def elixir_character_to_lsp(utf8_line, elixir_character) do
    utf8_line
    |> String.slice(0..(elixir_character - 2))
    |> to_utf16()
    |> byte_size()
    |> div(2)
  end

  defp to_utf16(b) do
    case :unicode.characters_to_binary(b, :utf8, :utf16) do
      b when is_binary(b) -> {:ok, b}
      {:error, _, _} = err -> err
      {:incomplete, _, _} -> {:error, :incomplete}
    end
  end

  defp to_utf8(b) do
    case :unicode.characters_to_binary(b, :utf16, :utf8) do
      b when is_binary(b) -> b
      {:error, _, _} = err -> err
      {:incomplete, _, _} -> {:error, :incomplete}
    end
  end
end
