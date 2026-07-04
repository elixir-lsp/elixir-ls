defmodule ElixirLS.LanguageServer.Providers.SelectionRanges do
  @moduledoc """
  This module provides document/selectionRanges support

  https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_selectionRange

  There is no one good way to get selection ranges that is bot robust and accurate. This module uses a combination of
  different approaches. Each produces different ranges (possibly contradictory) that are finally merged and combined

  Algorithms providers currently used:
  1. Delimiter pairs `()` `[]` `{}` `%{}` `<<>>` and `do`/`else`/`rescue`/`after`/`catch`/`end`
     blocks, derived from the toxic2 `closing:` / `do:` / `end:` node metadata
  2. Indentation cell pairs (line analysis)
  3. Comment blocks (from the toxic2 comment stream)
  4. Symbol under cursor, via `ElixirSense.Core.SurroundContext.Toxic` (AST-based spans for
     navigable shapes; it falls back internally for purely lexical units like a bare `do`/`end`)
  5. AST node ranges (toxic2 `range:` metadata)

  The AST/delimiter/comment passes all come from the error-tolerant toxic2 parser; string/heredoc/
  sigil ranges come from the AST nodes (not a separate token pass). The indentation pass is pure
  line analysis.
  """

  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Providers.FoldingRange
  import ElixirLS.LanguageServer.RangeUtils

  def selection_ranges(text, positions, options \\ []) do
    lines = SourceFile.lines(text)
    full_file_range = full_range(lines)

    formatted_lines = FoldingRange.Line.format_string(text)

    # AST node ranges and comments both come from the error-tolerant toxic2 parser.
    # `range: true` attaches `range: {{start_line, start_col}, {end_line, end_col}}` (end-exclusive,
    # 1-based) to every node that corresponds to source; the literal_encoder gives bare literals a
    # meta slot so they carry a range too.
    {ast, _diagnostics, comments} =
      Toxic2.string_to_quoted_with_comments(text,
        token_metadata: true,
        range: true,
        literal_encoder: fn literal, meta ->
          {:ok, {:__block__, meta, [literal]}}
        end
      )

    # Neutralize `{:__error__, ...}` placeholder nodes once here rather than once per cursor
    # position - `delimiter_pair_ranges/4` and `ast_node_ranges/4` both walk this tree for every
    # requested position, so neutralizing inside them repeated an O(AST) traversal per cursor.
    # `surround_context_ranges/4` keeps the raw `ast` (it does its own handling).
    neutralized_parse_result =
      {:ok, ElixirSense.Core.Parser.neutralize_errors(ast, [], true)}

    comment_groups = group_comments(comments)

    cell_pairs =
      formatted_lines
      |> Enum.map(&FoldingRange.Indentation.extract_cell/1)
      |> FoldingRange.Indentation.pair_cells()

    for %GenLSP.Structures.Position{line: line, character: character} <- positions do
      {line, character} = SourceFile.lsp_position_to_elixir(lines, {line, character})
      # for convenance the code in this module uses 0 based indexing
      {line, character} = {line - 1, character - 1}

      cell_pair_ranges = cell_pair_ranges(lines, cell_pairs, line, character)

      delimiter_pair_ranges =
        delimiter_pair_ranges(neutralized_parse_result, lines, line, character)
        |> deduplicate

      comment_block_ranges = comment_block_ranges(lines, comment_groups, line, character)

      ast_node_ranges = ast_node_ranges(neutralized_parse_result, line, character, options)

      surround_context_ranges = surround_context_ranges(ast, text, line, character)

      merged_ranges =
        [full_file_range | delimiter_pair_ranges]
        |> merge_ranges_lists([full_file_range | cell_pair_ranges])
        |> merge_ranges_lists([full_file_range | comment_block_ranges])
        |> merge_ranges_lists([full_file_range | surround_context_ranges])
        |> merge_ranges_lists([full_file_range | ast_node_ranges])

      if not increasingly_narrowing?(merged_ranges) do
        raise "merged_ranges are not increasingly narrowing"
      end

      to_nested_lsp_message(merged_ranges, lines)
    end
  end

  defp to_nested_lsp_message(ranges, lines) do
    ranges
    |> Enum.reduce(nil, fn selection_range, parent ->
      range(start_line_elixir, start_character_elixir, end_line_elixir, end_character_elixir) =
        selection_range

      # positions are 0-based
      {start_line_lsp, start_character_lsp} =
        SourceFile.elixir_position_to_lsp(
          lines,
          {start_line_elixir + 1, start_character_elixir + 1}
        )

      {end_line_lsp, end_character_lsp} =
        SourceFile.elixir_position_to_lsp(
          lines,
          {end_line_elixir + 1, end_character_elixir + 1}
        )

      %GenLSP.Structures.SelectionRange{
        range: %GenLSP.Structures.Range{
          start: %GenLSP.Structures.Position{line: start_line_lsp, character: start_character_lsp},
          end: %GenLSP.Structures.Position{line: end_line_lsp, character: end_character_lsp}
        },
        parent: parent
      }
    end)
  end

  def cell_pair_ranges(lines, cell_pairs, line, character) do
    for {{start_line, start_character}, {end_line, _end_line_start_character}} <-
          cell_pairs,
        (start_line < line or (start_line == line and start_character <= character)) and
          end_line > line do
      line_length = lines |> Enum.at(end_line - 1, "") |> String.length()
      second_line = lines |> Enum.at(start_line + 1, "")

      second_line_indent =
        String.length(second_line) - String.length(String.trim_leading(second_line))

      [range(start_line, start_character, end_line - 1, line_length)]
      |> Kernel.++(
        if(line >= start_line + 1,
          do: [range(start_line + 1, 0, end_line - 1, line_length)],
          else: []
        )
      )
      |> Kernel.++(
        if(
          line > start_line + 1 or
            (line == start_line + 1 and character >= second_line_indent),
          do: [range(start_line + 1, second_line_indent, end_line - 1, line_length)],
          else: []
        )
      )
    end
    |> List.flatten()
    |> sort_ranges_widest_to_narrowest()
  end

  # Outer/inner ranges for delimiter pairs - `()`/`[]`/`{}`/`%{}`/`<<>>` and `do`/`end` blocks -
  # derived from the toxic2 `closing:` / `do:` / `end:` node metadata. This replaces the old
  # tokenizer-driven token-pair pass (FoldingRange.Token/TokenPair). String/heredoc/sigil ranges,
  # which the old special-token pass produced, already come from `ast_node_ranges` (the toxic AST
  # nodes carry `range:`), so they are not reproduced here.
  # `ast` is already neutralized by the caller (`selection_ranges/3`).
  def delimiter_pair_ranges({:ok, ast}, lines, line, character) do
    {_ast, {acc, _stack}} =
      Macro.traverse(
        ast,
        {[], [nil]},
        fn node, {acc, [parent | _] = stack} ->
          new = pair_ranges_for(node, parent, lines, line, character)
          stack = if match?({_, _, _}, node), do: [node | stack], else: stack
          {node, {new ++ acc, stack}}
        end,
        fn
          {_, _, _} = node, {acc, [_ | tail]} -> {node, {acc, tail}}
          other, {acc, stack} -> {other, {acc, stack}}
        end
      )

    acc
    |> sort_ranges_widest_to_narrowest()
    |> deduplicate()
  end

  def delimiter_pair_ranges(_, _, _, _), do: []

  defp pair_ranges_for({:->, meta, _args}, _parent, _lines, line, character)
       when is_list(meta) do
    # stab clause `pattern -> body`: emit the "pattern .. ->" span (the clause node range and the
    # pattern/body node ranges already come from `ast_node_ranges`). The `:->` node meta line/column
    # is the arrow position.
    with range(csl, csc, _, _) <- range_from_meta(meta),
         arrow_line when is_integer(arrow_line) <- Keyword.get(meta, :line),
         arrow_col when is_integer(arrow_col) <- Keyword.get(meta, :column) do
      pattern_with_arrow = range(csl, csc, arrow_line - 1, arrow_col - 1 + 2)
      if in?(pattern_with_arrow, {line, character}), do: [pattern_with_arrow], else: []
    else
      _ -> []
    end
  end

  defp pair_ranges_for({_form, meta, _args} = node, parent, lines, line, character)
       when is_list(meta) do
    cond do
      Keyword.has_key?(meta, :do) and Keyword.has_key?(meta, :end) ->
        do_block_ranges(node, lines, line, character)

      Keyword.has_key?(meta, :closing) and Keyword.has_key?(meta, :range) ->
        container_ranges(node, parent, line, character)

      true ->
        []
    end
  end

  defp pair_ranges_for(_node, _parent, _lines, _line, _character), do: []

  # `(`/`[`/`{`/`%{`/`<<` ... pairs. `closing:` gives the close delimiter; the open delimiter and
  # the delimiter lengths depend on the node kind.
  defp container_ranges({form, meta, args}, parent, line, character) do
    [line: close_line1, column: close_col1] = Keyword.fetch!(meta, :closing)
    # the node's own line/column anchors the open delimiter: for a list/tuple/map/bitstring it is
    # the range start; for a call `fun(`/`Mod.fun(` it is the (function) name start.
    node_line = Keyword.fetch!(meta, :line) - 1
    node_col = Keyword.fetch!(meta, :column) - 1

    {open_line, open_col, open_len, close_len} =
      if Keyword.get(meta, :from_brackets) == true do
        # `x[y]` is lowered to `Access.get(x, y)`; the `[` sits right after the first argument `x`.
        case args do
          [first | _] ->
            case node_range_from_meta(first) do
              range(_, _, el, ec) -> {el, ec, 1, 1}
              _ -> {node_line, node_col, 1, 1}
            end

          _ ->
            {node_line, node_col, 1, 1}
        end
      else
        delimiters(form, parent, node_line, node_col)
      end

    close_line = close_line1 - 1
    close_col = close_col1 - 1
    outer = range(open_line, open_col, close_line, close_col + close_len)

    # half-open (end EXCLUSIVE): adjacent sibling containers (`foo[bar][baz]`) share a boundary
    # column; an inclusive check would emit both non-nested ranges and break the merge invariant.
    if half_open?(outer, line, character) do
      inner_start = open_col + open_len
      cursor_past_open = open_line < line or (open_line == line and inner_start <= character)
      cursor_before_close = close_line > line or (close_line == line and close_col >= character)

      if cursor_past_open and cursor_before_close do
        [range(open_line, inner_start, close_line, close_col), outer]
      else
        [outer]
      end
    else
      []
    end
  end

  # Returns {open_line, open_col, open_len, close_len} (0-based) for the node kind.
  defp delimiters(:%{}, parent, rsl, rsc) do
    # struct map (`%Mod{...}`): the node range starts at `{`. bare map (`%{...}`): range starts at
    # `%`, so the `{` is one column further right.
    open_col = if match?({:%, _, _}, parent), do: rsc, else: rsc + 1
    {rsl, open_col, 1, 1}
  end

  defp delimiters(:<<>>, _parent, rsl, rsc), do: {rsl, rsc, 2, 2}

  defp delimiters(form, _parent, rsl, rsc) when form in [:__block__, :{}, :%] do
    # literal list/tuple wrapped by the literal_encoder, 3+ element tuple, or struct `%` node
    {rsl, rsc, 1, 1}
  end

  defp delimiters({:., _dmeta, [_left, sym]}, _parent, rsl, rsc) when is_atom(sym) do
    # remote call `Mod.fun(...)` - the `(` sits right after the function name
    {rsl, rsc + String.length(Atom.to_string(sym)), 1, 1}
  end

  defp delimiters(form, _parent, rsl, rsc) when is_atom(form) do
    # local call `fun(...)` - the `(` sits right after the name
    {rsl, rsc + String.length(Atom.to_string(form)), 1, 1}
  end

  defp delimiters(_form, _parent, rsl, rsc), do: {rsl, rsc, 1, 1}

  # `do`/`else`/`catch`/`rescue`/`after`/`end` block. Pairs CONSECUTIVE section keywords
  # (`(do, else)`, `(else, end)`, or just `(do, end)`) and, for each pair containing the cursor,
  # emits an outer range (keyword start .. next keyword start) and an inner range. For a `..end`
  # pair the inner is the body lines (line-based); for a `..keyword` pair the inner runs from the
  # END of the first keyword to the next keyword. The `do`/`end` positions come from the node meta;
  # the `else`/`catch`/`rescue`/`after` positions come from the section keys in the node's args
  # (wrapped with `range:` by the literal_encoder). This mirrors the old token-pair behavior.
  defp do_block_ranges({_form, meta, _args} = node, lines, line, character) do
    [line: do_line1, column: do_col1] = Keyword.fetch!(meta, :do)
    [line: end_line1, column: end_col1] = Keyword.fetch!(meta, :end)

    sections =
      [{:do, {do_line1 - 1, do_col1 - 1}} | block_section_keywords(node)]
      |> Enum.uniq_by(fn {_name, pos} -> pos end)
      |> Enum.sort_by(fn {_name, pos} -> pos end)

    boundaries = sections ++ [{:end, {end_line1 - 1, end_col1 - 1}}]

    boundaries
    |> Enum.zip(tl(boundaries))
    |> Enum.flat_map(fn {{name, {sl, sc}}, {next_name, {el, ec}}} ->
      {outer, inner} =
        if next_name == :end do
          outer = range(sl, sc, el, ec + 3)

          inner =
            if line > sl and line < el do
              line_length = lines |> Enum.at(el - 1, "") |> String.length()
              ir = range(sl + 1, 0, el - 1, line_length)
              if empty?(ir), do: nil, else: ir
            end

          {outer, inner}
        else
          outer = range(sl, sc, el, ec)
          ir = range(sl, sc + keyword_length(name), el, ec)
          {outer, if(empty?(ir), do: nil, else: ir)}
        end

      # Sections of a multi-section block (do/else/rescue/...) are PEERS, not nested. Select the
      # cursor's section with half-open containment (end EXCLUSIVE) so a cursor exactly on a section
      # keyword belongs to that section only - otherwise two sibling, non-nested ranges would be
      # emitted and break the "increasingly narrowing" invariant.
      if half_open?(outer, line, character) do
        [outer, inner] |> Enum.reject(&is_nil/1)
      else
        []
      end
    end)
  end

  # cursor in [range_start, range_end): start inclusive, end EXCLUSIVE.
  defp half_open?(range(sl, sc, el, ec), line, character) do
    (sl < line or (sl == line and sc <= character)) and
      (el > line or (el == line and ec > character))
  end

  defp keyword_length(:do), do: 2
  defp keyword_length(:else), do: 4
  defp keyword_length(:catch), do: 5
  defp keyword_length(:rescue), do: 6
  defp keyword_length(:after), do: 5

  # Section keywords (`else`/`catch`/`rescue`/`after`) with start positions, read from the
  # block-section keys in the node's last argument.
  defp block_section_keywords({_form, _meta, args}) when is_list(args) do
    case List.last(args) do
      list when is_list(list) ->
        for {key, _body} <- list, kw = section_keyword(key), do: kw

      _ ->
        []
    end
  end

  defp block_section_keywords(_node), do: []

  defp section_keyword({:__block__, kmeta, [name]})
       when name in [:else, :catch, :rescue, :after] do
    case range_from_meta(kmeta) do
      range(sl, sc, _, _) -> {name, {sl, sc}}
      _ -> nil
    end
  end

  defp section_keyword(_key), do: nil

  def comment_block_ranges(lines, comment_groups, line, character) do
    for group <- comment_groups,
        group != [],
        {{{end_line, end_line_start_character}, _}, {{start_line, start_character}, _}} =
          FoldingRange.Helpers.first_and_last_of_list(group),
        (start_line < line or (start_line == line and start_character <= character)) and
          (end_line > line or (end_line == line and end_line_start_character <= character)) do
      case group do
        [_] ->
          line_length = lines |> Enum.at(start_line, "") |> String.length()
          full_line_range = range(start_line, 0, start_line, line_length)
          [full_line_range, range(start_line, start_character, start_line, line_length)]

        _ ->
          end_line_length = lines |> Enum.at(end_line, "") |> String.length()
          full_block_full_line_range = range(start_line, 0, end_line, end_line_length)
          full_block_range = range(start_line, start_character, end_line, end_line_length)

          [full_block_full_line_range, full_block_range] ++
            Enum.find_value(group, fn {{cursor_line, cursor_line_character}, _} ->
              if cursor_line == line do
                cursor_line_length = lines |> Enum.at(cursor_line, "") |> String.length()

                line_range =
                  range(
                    cursor_line,
                    cursor_line_character,
                    cursor_line,
                    cursor_line_length
                  )

                if cursor_line > start_line do
                  full_line_range = range(cursor_line, 0, cursor_line, cursor_line_length)
                  [full_line_range, line_range]
                else
                  # do not include full line range if cursor is on the first line of the block as it will conflict with full_block_range
                  [line_range]
                end
              end
            end)
      end
    end
    |> List.flatten()
  end

  @empty_node {:__block__, [], []}

  # `ast` is already neutralized by the caller (`selection_ranges/3`) - toxic2's best-effort
  # `{:__error__, meta, %{...}}` nodes (whose map args would crash `Macro.traverse`) have been
  # replaced there, once per parse rather than once per cursor position.
  def ast_node_ranges({:ok, ast}, line, character, _options) do
    {_new_ast, {acc, [@empty_node]}} =
      Macro.traverse(
        ast,
        {[], [@empty_node]},
        fn
          ast, {acc, [_parent_ast_from_stack | _] = parent_ast} ->
            matching_range =
              case node_range_from_meta(ast) do
                range(start_line, start_character, end_line, end_character) = range ->
                  if (start_line < line or (start_line == line and start_character <= character)) and
                       (end_line > line or (end_line == line and end_character >= character)) do
                    range
                  else
                    nil
                  end

                nil ->
                  nil
              end

            ranges_acc =
              if matching_range != nil do
                [matching_range | acc]
              else
                acc
              end

            ranges_acc =
              case ast do
                {_, meta, _} ->
                  parens_ranges =
                    for {:parens, parens_meta} <- meta,
                        parens_meta_closing = Keyword.get(parens_meta, :closing),
                        parens_meta_closing != nil,
                        parens_start_line = Keyword.fetch!(parens_meta, :line) - 1,
                        parens_start_character = Keyword.fetch!(parens_meta, :column) - 1,
                        parens_end_line = Keyword.fetch!(parens_meta_closing, :line) - 1,
                        parens_end_character = Keyword.fetch!(parens_meta_closing, :column),
                        (parens_start_line < line or
                           (parens_start_line == line and parens_start_character <= character)) and
                          (parens_end_line > line or
                             (parens_end_line == line and parens_end_character >= character)) do
                      # NOTE there may be multiple parens keys
                      outer_range =
                        range(
                          parens_start_line,
                          parens_start_character,
                          parens_end_line,
                          parens_end_character
                        )

                      if (parens_start_line < line or
                            (parens_start_line == line and parens_start_character + 1 <= character)) and
                           (parens_end_line > line or
                              (parens_end_line == line and parens_end_character - 1 >= character)) do
                        inner_range =
                          range(
                            parens_start_line,
                            parens_start_character + 1,
                            parens_end_line,
                            parens_end_character - 1
                          )

                        [outer_range, inner_range]
                      else
                        [outer_range]
                      end
                    end

                  List.flatten(parens_ranges) ++ ranges_acc

                _ ->
                  ranges_acc
              end

            parent_acc =
              if match?({_, _, _}, ast) do
                [ast | parent_ast]
              else
                parent_ast
              end

            {ast, {ranges_acc, parent_acc}}
        end,
        fn
          {_, _meta, _} = ast, {acc, [_ | tail]} ->
            {ast, {acc, tail}}

          other, {acc, stack} ->
            {other, {acc, stack}}
        end
      )

    acc
    |> sort_ranges_widest_to_narrowest()
    |> deduplicate
    |> fix_properties
  end

  def ast_node_ranges(_, _, _, _), do: []

  # Read a node's source range straight from the toxic2 `range:` meta (end-exclusive, 1-based),
  # converting to the provider's 0-based ranges. A 2-tuple (keyword/tuple pair) has no meta of its
  # own, so its range spans from its key's start to its value's end.
  # the map-update `|` (`%{m | k: v}`) carries no `range:` of its own; span it across its operands
  defp node_range_from_meta({:|, meta, [left, right]}) do
    range_from_meta(meta) || union_ranges(node_range_from_meta(left), node_range_from_meta(right))
  end

  defp node_range_from_meta({_form, meta, _args}) when is_list(meta) do
    case range_from_meta(meta) do
      # interpolation's `Kernel.to_string` node is macro-generated (no `range:`), but carries the
      # `#{` start (line/column) and the `}` (closing) - derive the `#{...}` span from those
      nil -> interpolation_range(meta)
      range -> range
    end
  end

  defp node_range_from_meta({left, right}) do
    case {child_range(left), child_range(right)} do
      {range(sl, sc, _, _), range(_, _, el, ec)} -> range(sl, sc, el, ec)
      {range(sl, sc, el, ec), nil} -> range(sl, sc, el, ec)
      {nil, range(sl, sc, el, ec)} -> range(sl, sc, el, ec)
      {nil, nil} -> nil
    end
  end

  defp node_range_from_meta([_ | _] = list) do
    # a keyword/pair list (`a: 1, b: 2`) is a plain list with no meta of its own; span it from the
    # first pair's start to the last pair's end
    if Enum.all?(list, &match?({_key, _value}, &1)) do
      case {node_range_from_meta(List.first(list)), node_range_from_meta(List.last(list))} do
        {range(sl, sc, _, _), range(_, _, el, ec)} -> range(sl, sc, el, ec)
        _ -> nil
      end
    end
  end

  defp node_range_from_meta(_), do: nil

  defp range_from_meta(meta) do
    case Keyword.get(meta, :range) do
      {{start_line, start_column}, {end_line, end_column}} ->
        range(start_line - 1, start_column - 1, end_line - 1, end_column - 1)

      _ ->
        nil
    end
  end

  defp child_range({_form, meta, _args}) when is_list(meta), do: range_from_meta(meta)
  defp child_range(_), do: nil

  defp union_ranges(range(sl, sc, _, _), range(_, _, el, ec)), do: range(sl, sc, el, ec)
  defp union_ranges(range(sl, sc, el, ec), nil), do: range(sl, sc, el, ec)
  defp union_ranges(nil, range(sl, sc, el, ec)), do: range(sl, sc, el, ec)
  defp union_ranges(nil, nil), do: nil

  defp interpolation_range(meta) do
    with true <- Keyword.get(meta, :from_interpolation, false),
         [line: closing_line, column: closing_column] <- Keyword.get(meta, :closing),
         start_line when is_integer(start_line) <- Keyword.get(meta, :line),
         start_column when is_integer(start_column) <- Keyword.get(meta, :column) do
      range(start_line - 1, start_column - 1, closing_line - 1, closing_column)
    else
      _ -> nil
    end
  end

  # Group toxic2 comments into blocks compatible with `comment_block_ranges/4`: each block is a list
  # of `{{row, column}, "#"}` cells in reverse source order (most recent first), matching
  # `FoldingRange.CommentBlock.group_comments/1`. Only full-line comments form blocks (an inline
  # comment has `previous_eol_count == 0`); a blank line between comments (`previous_eol_count >= 2`)
  # starts a new block.
  defp group_comments(comments) do
    comments
    |> Enum.filter(&(&1.previous_eol_count > 0))
    |> Enum.reduce([], fn comment, groups ->
      cell = {comment.line - 1, comment.column - 1}
      entry = {cell, "#"}

      case groups do
        [[{{previous_row, _}, _} | _] = current | rest]
        when comment.previous_eol_count == 1 and comment.line - 1 == previous_row + 1 ->
          [[entry | current] | rest]

        _ ->
          [[entry] | groups]
      end
    end)
  end

  # Symbol under the cursor. Goes through the toxic2-backed classifier (the same entry point the
  # navigation providers use) rather than `Code.Fragment.surround_context` directly: spans for
  # navigable shapes come from the AST `range:` metadata, and only lexical-only units (a bare
  # `do`/`end`, exotic operators) reach the internal Code.Fragment fallback. The already-parsed
  # `ast` is reused so this does not trigger a second parse per cursor position.
  def surround_context_ranges(ast, text, line, character) do
    case ElixirSense.Core.SurroundContext.Toxic.surround_context(
           ast,
           text,
           {line + 1, character + 1}
         ) do
      :none ->
        []

      %{begin: {start_line, start_character}, end: {end_line, end_character}} ->
        [range(start_line - 1, start_character - 1, end_line - 1, end_character - 1)]
    end
  end
end
