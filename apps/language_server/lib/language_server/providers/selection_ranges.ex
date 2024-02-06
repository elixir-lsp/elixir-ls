defmodule ElixirLS.LanguageServer.Providers.SelectionRanges do
  @moduledoc """
  This module provides document/selectionRanges support

  https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_selectionRange
  """

  alias ElixirLS.LanguageServer.{SourceFile}
  alias ElixirLS.LanguageServer.Providers.FoldingRange
  import ElixirLS.LanguageServer.Protocol
  import ElixirLS.LanguageServer.RangeUtils
  alias ElixirLS.LanguageServer.AstUtils

  defp token_length(:end), do: 3
  defp token_length(token) when token in [:"(", :"[", :"{", :")", :"]", :"}"], do: 1
  defp token_length(token) when token in [:"<<", :">>", :do, :fn], do: 2
  defp token_length(_), do: 0

  @stop_tokens [:",", :";", :eol, :eof, :pipe_op]

  def selection_ranges(text, positions) do
    lines = SourceFile.lines(text)
    full_file_range = full_range(lines)

    tokens = FoldingRange.Token.format_string(text)

    token_pairs = FoldingRange.TokenPair.pair_tokens(tokens)

    stop_tokens = get_stop_tokens_in_token_pairs(tokens, token_pairs)

    special_token_groups =
      for group <- FoldingRange.SpecialToken.group_tokens(tokens) do
        FoldingRange.Helpers.first_and_last_of_list(group)
      end

    formatted_lines = FoldingRange.Line.format_string(text)

    comment_groups =
      formatted_lines
      |> FoldingRange.CommentBlock.group_comments()

    parse_result =
      Code.string_to_quoted(text,
        token_metadata: true,
        columns: true,
        unescape: false,
        literal_encoder: fn literal, meta ->
          {:ok, {:__block__, meta, [literal]}}
        end
      )

    cell_pairs =
      formatted_lines
      |> Enum.map(&FoldingRange.Indentation.extract_cell/1)
      |> FoldingRange.Indentation.pair_cells()

    for %{"line" => line, "character" => character} <- positions do
      {line, character} = SourceFile.lsp_position_to_elixir(lines, {line, character})
      # for convenance the code in this module uses 0 based indexing
      {line, character} = {line - 1, character - 1}

      cell_pair_ranges = cell_pair_ranges(lines, cell_pairs, line, character)

      token_pair_ranges =
        token_pair_ranges(lines, token_pairs, stop_tokens, line, character)
        |> deduplicate

      special_token_group_ranges =
        special_token_group_ranges(special_token_groups, line, character)

      comment_block_ranges = comment_block_ranges(lines, comment_groups, line, character)

      ast_node_ranges = ast_node_ranges(parse_result, line, character)

      surround_context_ranges = surround_context_ranges(text, line, character)

      merged_ranges =
        [full_file_range | token_pair_ranges]
        |> merge_ranges_lists([full_file_range | cell_pair_ranges])
        |> merge_ranges_lists([full_file_range | special_token_group_ranges])
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

      %{
        "range" => range(start_line_lsp, start_character_lsp, end_line_lsp, end_character_lsp),
        "parent" => parent
      }
    end)
  end

  def token_pair_ranges(lines, token_pairs, stop_tokens, line, character) do
    token_pairs
    |> Enum.filter(fn {{_, {start_line, start_character, _}, _},
                       {end_token, {end_line, end_character, _}, _}} ->
      end_token_length = token_length(end_token)

      (start_line < line or (start_line == line and start_character <= character)) and
        (end_line > line or
           (end_line == line and end_character + end_token_length >= character))
    end)
    |> Enum.reduce([], fn {{start_token, {start_line, start_character, _}, _},
                           {end_token, {end_line, end_character, _}, _}} = pair,
                          acc ->
      stop_tokens_in_pair = Map.get(stop_tokens, pair, [])
      start_token_length = token_length(start_token)
      end_token_length = token_length(end_token)

      outer_range =
        range(start_line, start_character, end_line, end_character + end_token_length)

      case end_token do
        :end ->
          if line < start_line + 1 or line > end_line - 1 do
            # do not include inner range if cursor is outside, e.g.
            # do
            # ^ 
            [outer_range | acc]
          else
            line_length = lines |> Enum.at(end_line - 1) |> String.length()
            inner_range = range(start_line + 1, 0, end_line - 1, line_length)

            find_stop_token_range(stop_tokens_in_pair, pair, inner_range, line, character) ++
              [inner_range, outer_range | acc]
          end

        _ ->
          if (start_line == line and start_character + start_token_length > character) or
               (end_line == line and end_character < character) do
            # do not include inner range if cursor is outside, e.g.
            # << 123 >>
            # ^        ^
            [outer_range | acc]
          else
            inner_range =
              range(
                start_line,
                start_character + start_token_length,
                end_line,
                end_character
              )

            find_stop_token_range(stop_tokens_in_pair, pair, inner_range, line, character) ++
              [
                inner_range,
                outer_range | acc
              ]
          end
      end
    end)
    |> Enum.reverse()
  end

  defp find_stop_token_range([], _, _, _, _), do: []

  defp find_stop_token_range(tokens, {begin_token, end_token}, inner_range, line, character) do
    {_, found} =
      Enum.reduce_while(tokens ++ [{end_token, nil, nil}], {{begin_token, nil, nil}, []}, fn
        {token, before_stop, _} = token_tuple, {{previous_token, _, after_previous}, _} ->
          {_, {start_line, start_character, _}, _} = previous_token
          {_, {end_line, end_character, _}, _} = token

          if (start_line < line or (start_line == line and start_character <= character)) and
               (end_line > line or (end_line == line and end_character >= character)) do
            # dbg({previous_token, after_previous, before_stop, token})
            {end_line, end_character} =
              case before_stop do
                {kind, _, _} when kind in [:bin_string, :list_string] ->
                  {end_line, end_character}

                {kind, {before_start_line, before_start_character, list}, _} when is_list(list) ->
                  length_modifier =
                    if kind == :atom do
                      1
                    else
                      0
                    end

                  {before_start_line, before_start_character + length(list) + length_modifier}

                {_, {before_start_line, before_start_character, _}, list} when is_list(list) ->
                  {before_start_line, before_start_character + length(list)}

                {:atom_quoted, {before_start_line, before_start_character, _}, atom} ->
                  {before_start_line, before_start_character + String.length(to_string(atom)) + 3}

                _ ->
                  {end_line, end_character}
              end

            {start_line, start_character} =
              case after_previous do
                {_, {after_end_line, after_end_character, _}, _} ->
                  {after_end_line, after_end_character}

                nil ->
                  {start_line, start_character}
              end

            # TODO
            {:halt,
             {token_tuple,
              [
                intersection(
                  range(start_line, start_character, end_line, end_character),
                  inner_range
                )
              ]}}
          else
            {:cont, {token_tuple, []}}
          end
      end)

    found
  end

  def cell_pair_ranges(lines, cell_pairs, line, character) do
    for {{start_line, start_character}, {end_line, _end_line_start_character}} <-
          cell_pairs,
        (start_line < line or (start_line == line and start_character <= character)) and
          end_line > line do
      line_length = lines |> Enum.at(end_line - 1) |> String.length()
      second_line = lines |> Enum.at(start_line + 1)

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

  def special_token_group_ranges(special_token_groups, line, character) do
    for {{_end_token, {end_line, end_character, _}, _},
         {_start_token, {start_line, start_character, _}, _}} <- special_token_groups,
        end_token_length = 0,
        (start_line < line or (start_line == line and start_character <= character)) and
          (end_line > line or
             (end_line == line and end_character + end_token_length >= character)) do
      range(start_line, start_character, end_line, end_character)
    end
  end

  def comment_block_ranges(lines, comment_groups, line, character) do
    for group <- comment_groups,
        group != [],
        {{{end_line, end_line_start_character}, _}, {{start_line, start_character}, _}} =
          FoldingRange.Helpers.first_and_last_of_list(group),
        (start_line < line or (start_line == line and start_character <= character)) and
          (end_line > line or (end_line == line and end_line_start_character <= character)) do
      case group do
        [_] ->
          line_length = lines |> Enum.at(start_line) |> String.length()
          full_line_range = range(start_line, 0, start_line, line_length)
          [full_line_range, range(start_line, start_character, start_line, line_length)]

        _ ->
          end_line_length = lines |> Enum.at(end_line) |> String.length()
          full_block_full_line_range = range(start_line, 0, end_line, end_line_length)
          full_block_range = range(start_line, start_character, end_line, end_line_length)

          [full_block_full_line_range, full_block_range] ++
            Enum.find_value(group, fn {{cursor_line, cursor_line_character}, _} ->
              if cursor_line == line do
                cursor_line_length = lines |> Enum.at(cursor_line) |> String.length()

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

  def ast_node_ranges({:ok, ast}, line, character) do
    {_new_ast, {acc, []}} =
      Macro.traverse(
        ast,
        {[], []},
        fn
          {form, _meta, _args} = ast, {acc, parent_ast} ->
            parent_ast_from_stack =
              case parent_ast do
                [] -> []
                [item | _] -> item
              end

            case AstUtils.node_range(ast) do
              range(start_line, start_character, end_line, end_character) ->
                start_character =
                  if form == :%{} and match?({:%, _, _}, parent_ast_from_stack) and
                       Version.match?(System.version(), "< 1.16.2") do
                    # workaround elixir bug
                    # https://github.com/elixir-lang/elixir/commit/fd4e6b530c0e010712b06909c89820b08e49c238
                    # undo column offset for structs inner map node
                    start_character + 1
                  else
                    start_character
                  end

                range = range(start_line, start_character, end_line, end_character)

                if (start_line < line or (start_line == line and start_character <= character)) and
                     (end_line > line or (end_line == line and end_character >= character)) do
                  # dbg({ast, range, parent_ast_from_stack})
                  {ast, {[range | acc], [ast | parent_ast]}}
                else
                  # dbg({ast, range, {line, character}, "outside"})
                  {ast, {acc, [ast | parent_ast]}}
                end

              nil ->
                # dbg({ast, "nil"})
                {ast, {acc, [ast | parent_ast]}}
            end

          other, {acc, parent_ast} ->
            # dbg({other, "other"})
            {other, {acc, parent_ast}}
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
  end

  def ast_node_ranges(_, _, _), do: []

  def surround_context_ranges(text, line, character) do
    case Code.Fragment.surround_context(text, {line + 1, character + 1}) do
      :none ->
        []

      %{begin: {start_line, start_character}, end: {end_line, end_character}} ->
        [range(start_line - 1, start_character - 1, end_line - 1, end_character - 1)]
    end
  end

  def get_stop_tokens_in_token_pairs(tokens, token_pairs) do
    tokens_next = tl(tokens) ++ [nil]
    tokens_prev = [nil | Enum.slice(tokens, 0..-2//1)]
    tokens_prev_next = Enum.zip([tokens_prev, tokens, tokens_next])

    for {prev_token, {token, {line, character, _}, _} = token_tuple, next_token} <-
          tokens_prev_next,
        token in @stop_tokens do
      pair =
        token_pairs
        |> Enum.filter(fn {{_, {start_line, start_character, _}, _},
                           {_, {end_line, end_character, _}, _}} ->
          (start_line < line or (start_line == line and start_character <= character)) and
            (end_line > line or (end_line == line and end_character >= character))
        end)
        |> Enum.min_by(
          fn {{_, {start_line, start_character, _}, _}, {_, {end_line, end_character, _}, _}} ->
            {end_line - start_line, end_character - start_character}
          end,
          &<=/2,
          fn -> nil end
        )

      {pair, {token_tuple, prev_token, next_token}}
    end
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {pair, tuples} ->
      {pair, Enum.map(tuples, &elem(&1, 1))}
    end)
    |> Map.new()
  end
end
