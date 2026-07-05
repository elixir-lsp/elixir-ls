defmodule ElixirLS.LanguageServer.Providers.SemanticTokens do
  @moduledoc """
  `textDocument/semanticTokens` provider.

  A sparse, name-level overlay on top of the TextMate grammar (see `SEMANTIC_TOKENS.md` in the
  toxic2 repo). The heavy lifting — token classification from the tolerant lexer + green CST —
  lives in `Toxic2.SemanticTokens`; this module only:

    1. advertises the legend,
    2. converts toxic2's 1-based codepoint columns to LSP UTF-16 offsets, and
    3. delta-encodes the spans into the flat `[Δline, Δstart, length, type, modifiers]` stream.

  Toxic2 guarantees every emitted span is single-line and source-ordered, so there is no
  multiline/overlap handling here.
  """

  import Bitwise

  alias ElixirLS.LanguageServer.SourceFile
  alias GenLSP.Structures.{SemanticTokens, SemanticTokensLegend, Range, Position}

  # The legend. APPEND-ONLY — clients cache types/modifiers by index, so never reorder or remove.
  @token_types [
    :namespace,
    :type,
    :class,
    :function,
    :method,
    :macro,
    :property,
    :number,
    :variable,
    :atom,
    :attribute,
    :typespec,
    :sigil,
    :capture
  ]
  @token_modifiers [:definition, :declaration, :readonly, :documentation, :deprecated, :defaultLibrary]

  @type_index @token_types |> Enum.with_index() |> Map.new()
  @modifier_bit @token_modifiers
                |> Enum.with_index()
                |> Map.new(fn {m, i} -> {m, bsl(1, i)} end)

  @doc "The legend advertised in `SemanticTokensOptions`."
  @spec legend() :: SemanticTokensLegend.t()
  def legend do
    %SemanticTokensLegend{
      token_types: Enum.map(@token_types, &Atom.to_string/1),
      token_modifiers: Enum.map(@token_modifiers, &Atom.to_string/1)
    }
  end

  @doc "Full-document semantic tokens."
  @spec full(SourceFile.t()) :: {:ok, SemanticTokens.t()}
  def full(%SourceFile{text: text}) do
    {:ok, %SemanticTokens{data: encode(Toxic2.SemanticTokens.tokens(text), lines(text))}}
  end

  @doc "Semantic tokens restricted to `range` (line-granular filter; the lex is whole-file)."
  @spec range(SourceFile.t(), Range.t()) :: {:ok, SemanticTokens.t()}
  def range(%SourceFile{text: text}, %Range{
        start: %Position{line: start_line},
        end: %Position{line: end_line, character: end_char}
      }) do
    spans =
      text
      |> Toxic2.SemanticTokens.tokens()
      |> Enum.filter(fn {sl, _sc, _el, _ec, _t, _m} ->
        line0 = sl - 1
        # LSP range end is EXCLUSIVE: a token on the end line counts only if the range actually
        # extends into it (end character > 0). Line-granular is fine — over-returning within the
        # start/end lines is allowed; crossing past an exclusive end boundary is not.
        line0 >= start_line and (line0 < end_line or (line0 == end_line and end_char > 0))
      end)

    {:ok, %SemanticTokens{data: encode(spans, lines(text))}}
  end

  # --- encoding ----------------------------------------------------------------------------

  defp lines(text), do: text |> String.split("\n") |> List.to_tuple()

  # toxic2 spans are already source-ordered and single-line. Fold into the LSP relative encoding,
  # carrying the previous token's (line, utf16-start). Zero-length and out-of-bounds spans are
  # dropped defensively.
  #
  # Codepoint→UTF-16 conversion uses a running per-line cursor: because spans are ordered and
  # non-overlapping, each line is walked at most once for the whole span stream (instead of
  # re-walking from column 0 twice per token, which is quadratic on long dense lines).
  defp encode(spans, lines) do
    line_count = tuple_size(lines)

    {rows, _prev_line, _prev_start, _cursor} =
      Enum.reduce(spans, {[], 0, 0, nil}, fn {sl, sc, _el, ec, type, mods},
                                             {acc, prev_line, prev_start, cursor} ->
        line0 = sl - 1

        with tindex when is_integer(tindex) <- Map.get(@type_index, type),
             true <- line0 >= 0 and line0 < line_count do
          cursor = seek(cursor, line0, sc - 1, lines)
          {_, _, _, start16} = cursor = advance(cursor, sc - 1)
          {_, _, _, end16} = cursor = advance(cursor, ec - 1)
          length = end16 - start16

          if length > 0 do
            delta_line = line0 - prev_line
            delta_start = if delta_line == 0, do: start16 - prev_start, else: start16
            row = [delta_line, delta_start, length, tindex, modifier_bits(mods)]
            {[row | acc], line0, start16, cursor}
          else
            {acc, prev_line, prev_start, cursor}
          end
        else
          _ -> {acc, prev_line, prev_start, cursor}
        end
      end)

    rows |> Enum.reverse() |> List.flatten()
  end

  # Cursor: {line0, rest_of_line_binary, codepoint_pos, utf16_pos}. Reuse it when the target is
  # on the same line at-or-after the current position; otherwise rewind to the line start.
  defp seek({line0, _rest, cp, _u16} = cursor, line0, target_cp, _lines) when cp <= target_cp,
    do: cursor

  defp seek(_cursor, line0, _target_cp, lines), do: {line0, elem(lines, line0), 0, 0}

  # Walk codepoints forward accumulating UTF-16 units; clamps at end of line (mirrors
  # CodeUnit.utf16_offset's pegging so malformed columns can't produce garbage).
  defp advance({_line0, _rest, cp, _u16} = cursor, target_cp) when cp >= target_cp, do: cursor

  defp advance({line0, <<c::utf8, rest::binary>>, cp, u16}, target_cp),
    do: advance({line0, rest, cp + 1, u16 + if(c >= 0x10000, do: 2, else: 1)}, target_cp)

  # Invalid UTF-8 byte: count it as one unit and keep going (SourceFile text should be valid).
  defp advance({line0, <<_b, rest::binary>>, cp, u16}, target_cp),
    do: advance({line0, rest, cp + 1, u16 + 1}, target_cp)

  defp advance({_line0, <<>>, _cp, _u16} = cursor, _target_cp), do: cursor

  defp modifier_bits(mods) do
    Enum.reduce(mods, 0, fn m, bits -> bor(bits, Map.get(@modifier_bit, m, 0)) end)
  end
end
