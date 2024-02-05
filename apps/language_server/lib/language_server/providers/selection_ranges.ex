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

  # TODO =>
  @stop_tokens [:",", :";", :eol]

  @binary_operators ~w[. ** * / + - ++ -- +++ --- .. <> in |> <<< >>> <<~ ~>> <~ ~> <~> < > <= >= == != === !== =~ && &&& and || ||| or = => :: when <- -> \\]a
  @unary_operators ~w[@ + - ! ^ not &]a
  @unary_and_binary_operators ~w[+ -]a

  def selection_ranges(text, positions) do
    lines = SourceFile.lines(text)
    full_file_range = full_range(lines)

    tokens = FoldingRange.Token.format_string(text) |> dbg(limit: :infinity)

    token_pairs = FoldingRange.TokenPair.pair_tokens(tokens) |> dbg

    stop_tokens = get_stop_tokens_in_token_pairs(tokens, token_pairs) |> dbg

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
      ) |> dbg

    cell_pairs =
      formatted_lines
      |> Enum.map(&FoldingRange.Indentation.extract_cell/1)
      |> FoldingRange.Indentation.pair_cells()

    for %{"line" => line, "character" => character} <- positions do
      {line, character} = SourceFile.lsp_position_to_elixir(lines, {line, character})
      # for convenance the code in this module uses 0 based indexing
      {line, character} = {line - 1, character - 1}

      cell_pair_ranges = cell_pair_ranges(lines, cell_pairs, line, character)

      token_pair_ranges = token_pair_ranges(lines, token_pairs, stop_tokens, line, character)
      |> deduplicate

      special_token_group_ranges =
        special_token_group_ranges(special_token_groups, line, character)

      comment_block_ranges = comment_block_ranges(lines, comment_groups, line, character)

      ast_node_ranges = ast_node_ranges(parse_result, line, character)

      surround_context_ranges = surround_context_ranges(text, line, character)

      merged_ranges =
        [full_file_range | token_pair_ranges] |> dbg
        |> merge_ranges_lists([full_file_range | cell_pair_ranges] |> dbg)
        |> merge_ranges_lists([full_file_range | special_token_group_ranges] |> dbg)
        |> merge_ranges_lists([full_file_range | comment_block_ranges] |> dbg)
        |> merge_ranges_lists([full_file_range | surround_context_ranges] |> dbg)
        |> merge_ranges_lists([full_file_range | ast_node_ranges] |> dbg)

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

  # this function differs from the one in SourceFile - it returns utf8 ranges
  defp full_range(lines) do
    utf8_size =
      lines
      |> List.last()
      |> String.length()

    range(0, 0, Enum.count(lines) - 1, utf8_size)
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
      stop_tokens_in_pair = Map.get(stop_tokens, pair, []) |> dbg
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
            inner_range = range(
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
    {_, found} = Enum.reduce_while(tokens ++ [{end_token, nil, nil}], {{begin_token, nil, nil}, []}, fn
      {token, before_stop, _} = token_tuple, {{previous_token, _, after_previous}, _} ->
        {_, {start_line, start_character, _}, _} = previous_token
        {_, {end_line, end_character, _}, _} = token
        if (start_line < line or start_line == line and start_character <= character) and (end_line > line or end_line == line and end_character >= character) do
          dbg({previous_token, after_previous, before_stop, token})
          {end_line, end_character} = case before_stop do
            {kind, _, _} when kind in [:bin_string, :list_string] ->
              {end_line, end_character}
            {kind, {before_start_line, before_start_character, list}, _} when is_list(list) ->
              length_modifier = if kind == :atom do
                1
              else
                0
              end
              {before_start_line, before_start_character + length(list) + length_modifier}
            {_, {before_start_line, before_start_character, _}, list} when is_list(list) ->
              {before_start_line, before_start_character + length(list)}
            {:atom_quoted, {before_start_line, before_start_character, _}, atom} ->
              {before_start_line, before_start_character + String.length(to_string(atom)) + 3}
            _ -> {end_line, end_character}
          end
          {start_line, start_character} = case after_previous do 
            {_, {after_end_line, after_end_character, _}, _} ->
              {after_end_line, after_end_character}
            nil ->
              {start_line, start_character}
          end
          # TODO
          {:halt, {token_tuple, [intersection(range(start_line, start_character, end_line, end_character), inner_range)]}}
        else
          {:cont, {token_tuple, []}}
        end
    end)
    found |> dbg
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
          {form, meta, args} = ast, {acc, parent_ast} ->
            parent_ast_from_stack =
              case parent_ast do
                [] -> []
                [item | _] -> item
              end

            # {start_line, start_character} =
            #   cond do
            #     node == :%{} and match?({:%, _, _}, parent_ast_from_stack) ->
            #       # get line and column from parent % node, current node meta points to {
            #       {_, parent_meta, _} = parent_ast_from_stack

            #       {Keyword.get(parent_meta, :line, 1) - 1,
            #        Keyword.get(parent_meta, :column, 1) - 1}

            #     node in @binary_operators and match?([_, _], args) ->
            #       [left | _] = args
            #       # dbg(binding(), limit: :infinity)
            #       find_start_of_expression(left, {Keyword.get(meta, :line, 1) - 1, Keyword.get(meta, :column, 1) - 1})


                
            #     meta_line = meta[:line] ->
            #       {meta_line - 1, Keyword.get(meta, :column, 1) - 1}
                
            #     true ->
            #       find_start_of_expression(ast, {nil, nil})
            #   end

            # if start_line < 0 or start_character < 0 do
            #   dbg(ast)
            #   raise "could not find start of expression"
            # end

            # {end_line, end_character} =
            #   cond do
            #     node == :__aliases__ ->
            #       last = meta[:last]

            #       last_length =
            #         case List.last(args) do
            #           atom when is_atom(atom) -> atom |> to_string() |> String.length()
            #           _ -> 0
            #         end

            #       {last[:line] - 1, last[:column] - 1 + last_length}

            #     node in @binary_operators and match?([_, _], args) ->
            #       dbg(ast)
            #       dbg(parent_ast_from_stack)
            #       [_left, right] = args
            #       operator_length = node|> to_string() |> String.length()
            #       find_end_of_expression(right, parent_ast_from_stack, {start_line, start_character + operator_length})

            #     node in @unary_operators and match?([_], args) ->
            #       [right] = args
            #       operator_length = node|> to_string() |> String.length()
            #       find_end_of_expression(right, parent_ast_from_stack, {start_line, start_character + operator_length})

            #     end_location = meta[:end_of_expression] ->
            #       {end_location[:line] - 1, end_location[:column] - 1}

            #     end_location = meta[:end] ->
            #       {end_location[:line] - 1, end_location[:column] - 1 + 3}

            #     end_location = meta[:closing] ->
            #       closing_length =
            #         case node do
            #           :<<>> -> 2
            #           _ -> 1
            #         end

            #       {end_location[:line] - 1, end_location[:column] - 1 + closing_length}

            #     token = meta[:token] ->
            #       {start_line, start_character + String.length(token)}

            #     meta[:delimiter] && (is_list(node) or is_binary(node)) ->
            #       {start_line, start_character + String.length(to_string(node))}

            #     # TODO a few other cases

            #     #   parent_end_line =
            #     #   parent_meta_from_stack
            #     #   |> dbg()
            #     #   |> Keyword.get(:end, [])
            #     #   |> Keyword.get(:line) ->
            #     # # last expression in block does not have end_of_expression
            #     # parent_do_line = parent_meta_from_stack[:do][:line]

            #     # if parent_end_line > parent_do_line do
            #     #   # take end location from parent and assume end_of_expression is last char in previous line
            #     #   end_of_expression =
            #     #     Enum.at(lines, max(parent_end_line - 2, 0))
            #     #     |> String.length()

            #     #   SourceFile.elixir_position_to_lsp(
            #     #     lines,
            #     #     {parent_end_line - 1, end_of_expression + 1}
            #     #   )
            #     # else
            #     #   # take end location from parent and assume end_of_expression is last char before final ; trimmed
            #     #   line = Enum.at(lines, parent_end_line - 1)
            #     #   parent_end_column = parent_meta_from_stack[:end][:column]

            #     #   end_of_expression =
            #     #     line
            #     #     |> String.slice(0..(parent_end_column - 2))
            #     #     |> String.trim_trailing()
            #     #     |> String.replace_trailing(";", "")
            #     #     |> String.length()

            #     #   SourceFile.elixir_position_to_lsp(
            #     #     lines,
            #     #     {parent_end_line, end_of_expression + 1}
            #     #   )
            #     # end
            #     true ->
            #       find_end_of_expression(ast, parent_ast_from_stack, {start_line, start_character})
            #   end

            range = AstUtils.node_range(ast) |> dbg
            # range = try do
            #   AstUtils.node_range(ast)
            # rescue
            #   _ -> nil
            # end

            case range do
              range(start_line, start_character, end_line, end_character) = range ->
                start_character = if form == :"%{}" and match?({:%, _, _}, parent_ast_from_stack) do
                  # undo column offset for structs inner map node
                  start_character + 1
                else
                  start_character
                end
                range = range(start_line, start_character, end_line, end_character)
                if (start_line < line or (start_line == line and start_character <= character)) and
                    (end_line > line or (end_line == line and end_character >= character)) do
                      # range = range(start_line, start_character, end_line, end_character)
                      if not valid?(range) do
                        raise "invalid range"
                      end
                  # dbg({ast, range, parent_ast_from_stack})
                  {ast,
                  {[range | acc],
                    [ast | parent_ast]}}
                else
                  dbg({ast, range, {line, character}, "outside"})
                  {ast, {acc, [ast | parent_ast]}}
                end
              nil ->
                dbg({ast, "nil"})
                {ast, {acc, [ast | parent_ast]}}
              end

          other, {acc, parent_ast} ->
            dbg({other, "other"})
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
    for {prev_token, {token, {line, character, _}, _} = token_tuple, next_token} <- tokens_prev_next,
    token in @stop_tokens
    do
      pair = token_pairs
      |> Enum.filter(fn {{_, {start_line, start_character, _}, _}, {_, {end_line, end_character, _}, _}} ->
        (start_line < line or start_line == line and start_character <= character) and (end_line > line or end_line == line and end_character >= character)
      end)
      |> Enum.min_by(fn {{_, {start_line, start_character, _}, _}, {_, {end_line, end_character,_}, _}} ->
        {end_line - start_line, end_character - start_character}
      end, &<=/2,
      fn -> nil end)

      {pair, {token_tuple, prev_token, next_token}}
    end
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {pair, tuples} ->
      {pair, Enum.map(tuples, &elem(&1, 1))}
    end)
    |> Map.new()
  end

  def find_start_of_expression(ast, acc) do
    {_, soe} = Macro.prewalk(ast, acc, fn
      {kind, meta, _} = node, {line, column} ->
        if soe_line = meta[:line] do
          soe_line = soe_line - 1
          correction = if kind == :"%{}" do
            # TODO is is a bug in parser? column is invalid
            -1
          else
            0
          end
          soe_column = meta[:column] - 1 + correction
          if soe_line < line or (soe_line == line and soe_column <= column) do
            {node, {soe_line, soe_column}}
          else
            {node, {line, column}}
          end
        else
          {node, {line, column}}
        end
      node, acc ->
        {node, acc}
    end)
    dbg({ast, soe})
    case soe do
      {nil, nil} -> :ok
      {l, c} when l < 0 or c < 0 -> raise "invalid start of expression"
      _ -> :ok
    end
    soe
  end

  defp find_end_of_expression(ast, parent_node, acc) do
    {soe_line, soe_column} = find_start_of_expression(ast, {nil, nil})
      {soe_line, soe_column} = if {soe_line, soe_column} == {nil, nil} do
        acc
      else
        {soe_line, soe_column}
      end

    # try to find it in meta recursively
    {_, eoe} = Macro.prewalk(ast, acc, fn
      {node, meta, args} = ast, {line, column} ->
        {eoe_line, eoe_column} = cond do
          node == :__aliases__ ->
            last = meta[:last]

            last_length =
              case List.last(args) do
                atom when is_atom(atom) -> atom |> to_string() |> String.length()
                _ -> 0
              end

            {last[:line] - 1, last[:column] - 1 + last_length}

          end_location = meta[:end_of_expression] ->
            {end_location[:line] - 1, end_location[:column] - 1}

          end_location = meta[:end] ->
            {end_location[:line] - 1, end_location[:column] - 1 + 3}

          end_location = meta[:closing] ->
            closing_length =
              case node do
                :<<>> -> 2
                _ -> 1
              end

            {end_location[:line] - 1, end_location[:column] - 1 + closing_length}

          token = meta[:token] ->
            {soe_line, soe_column + String.length(token)}

          meta[:delimiter] && (is_list(node) or is_binary(node)) ->
            {soe_line, soe_column + String.length(to_string(node))}

          true ->
            {line, column}
        end

        if eoe_line > line or (eoe_line == line and eoe_column >= column) do
          {node, {eoe_line, eoe_column}}
        else
          {node, {line, column}}
        end
      node, acc ->
        {node, acc}
    end)
    
    eoe = if eoe == acc do
      # no end_of_expression in last expression in do block
      # get from parent meta
      case parent_node do
        {_, parent_meta, _} ->
          end_meta = parent_meta[:end]
          if end_meta do
            {end_meta[:line] - 1, end_meta[:column] - 1}
          else
            acc
          end
        _ -> acc
      end
    else
      eoe
    end

    # try to format the expression and count chars
    eoe = if eoe == acc do
      code = ast |> dbg |> Code.quoted_to_algebra |> Inspect.Algebra.format(:infinity) |> IO.iodata_to_binary()
      lines = code |> SourceFile.lines()
      case lines do
        [_] -> {soe_line, soe_column + String.length(code)}
        _ ->
          last_line = Enum.at(lines, -1)
          {soe_line + length(lines) - 1, String.length(last_line)}
      end
    else
      eoe
    end
    dbg({ast, eoe})
    eoe
  end
end
