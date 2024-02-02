defmodule ElixirLS.LanguageServer.Providers.SelectionRanges do
  @moduledoc """
  This module provides document/selectionRanges support

  https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_selectionRange
  """

  alias ElixirLS.LanguageServer.{SourceFile}
  alias ElixirLS.LanguageServer.Providers.FoldingRange
  import ElixirLS.LanguageServer.Protocol
  import ElixirLS.LanguageServer.RangeUtils

  defp token_length(:end), do: 3
  defp token_length(token) when token in [:"(", :"[", :"{", :")", :"]", :"}"], do: 1
  defp token_length(token) when token in [:"<<", :">>", :do, :fn], do: 2
  defp token_length(_), do: 0

  # @stop_tokens [:",", :";", :|]

  def selection_ranges(text, positions) do
    lines = SourceFile.lines(text)
    full_file_range = full_range(lines)

    tokens = FoldingRange.Token.format_string(text)

    token_pairs = FoldingRange.TokenPair.pair_tokens(tokens)

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
        literal_encoder: fn literal, meta ->
          {:ok, {literal, meta, nil}}
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

      cell_pair_ranges =
        ([full_file_range] ++
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
           end)
        |> List.flatten()

      cell_pair_ranges = sort_ranges_widest_to_narrowest(cell_pair_ranges)

      token_pair_ranges =
        token_pairs
        |> Enum.filter(fn {{_, {start_line, start_character, _}, _},
                           {end_token, {end_line, end_character, _}, _}} ->
          end_token_length = token_length(end_token)

          (start_line < line or (start_line == line and start_character <= character)) and
            (end_line > line or
               (end_line == line and end_character + end_token_length >= character))
        end)
        |> Enum.reduce([full_file_range], fn {{start_token, {start_line, start_character, _}, _},
                                              {end_token, {end_line, end_character, _}, _}},
                                             acc ->
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
                [range(start_line + 1, 0, end_line - 1, line_length), outer_range | acc]
              end

            _ ->
              if (start_line == line and start_character + start_token_length > character) or
                   (end_line == line and end_character < character) do
                # do not include inner range if cursor is outside, e.g.
                # << 123 >>
                # ^        ^
                [outer_range | acc]
              else
                [
                  range(
                    start_line,
                    start_character + start_token_length,
                    end_line,
                    end_character
                  ),
                  outer_range | acc
                ]
              end
          end
        end)
        |> Enum.reverse()

      special_token_group_ranges =
        [full_file_range] ++
          for {{_end_token, {end_line, end_character, _}, _},
               {_start_token, {start_line, start_character, _}, _}} <- special_token_groups,
              end_token_length = 0,
              (start_line < line or (start_line == line and start_character <= character)) and
                (end_line > line or
                   (end_line == line and end_character + end_token_length >= character)) do
            range(start_line, start_character, end_line, end_character)
          end

      comment_block_ranges =
        [full_file_range] ++
          (for group <- comment_groups,
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
           |> List.flatten())

      ast_ranges =
        case parse_result do
          {:ok, ast} ->
            {_new_ast, {acc, []}} =
              Macro.traverse(
                ast,
                {[full_file_range], []},
                fn
                  {node, meta, args} = ast, {acc, parent_ast} ->
                    parent_ast_from_stack =
                      case parent_ast do
                        [] -> []
                        [item | _] -> item
                      end

                    {start_line, start_character} =
                      cond do
                        node == :%{} and match?({:%, _, _}, parent_ast_from_stack) ->
                          # get line and column from parent % node, current node meta points to {
                          {_, parent_meta, _} = parent_ast_from_stack

                          {Keyword.get(parent_meta, :line, 0) - 1,
                           Keyword.get(parent_meta, :column, 0) - 1}

                        true ->
                          {Keyword.get(meta, :line, 0) - 1, Keyword.get(meta, :column, 0) - 1}
                      end

                    {end_line, end_character} =
                      cond do
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
                          {start_line, start_character + String.length(token)}

                        # is_atom(node) ->
                        #   {start_line, start_character + String.length(to_string(node))}

                        meta[:delimiter] && (is_list(node) or is_binary(node)) ->
                          {start_line, start_character + String.length(to_string(node))}

                        # TODO a few other cases

                        #   parent_end_line =
                        #   parent_meta_from_stack
                        #   |> dbg()
                        #   |> Keyword.get(:end, [])
                        #   |> Keyword.get(:line) ->
                        # # last expression in block does not have end_of_expression
                        # parent_do_line = parent_meta_from_stack[:do][:line]

                        # if parent_end_line > parent_do_line do
                        #   # take end location from parent and assume end_of_expression is last char in previous line
                        #   end_of_expression =
                        #     Enum.at(lines, max(parent_end_line - 2, 0))
                        #     |> String.length()

                        #   SourceFile.elixir_position_to_lsp(
                        #     lines,
                        #     {parent_end_line - 1, end_of_expression + 1}
                        #   )
                        # else
                        #   # take end location from parent and assume end_of_expression is last char before final ; trimmed
                        #   line = Enum.at(lines, parent_end_line - 1)
                        #   parent_end_column = parent_meta_from_stack[:end][:column]

                        #   end_of_expression =
                        #     line
                        #     |> String.slice(0..(parent_end_column - 2))
                        #     |> String.trim_trailing()
                        #     |> String.replace_trailing(";", "")
                        #     |> String.length()

                        #   SourceFile.elixir_position_to_lsp(
                        #     lines,
                        #     {parent_end_line, end_of_expression + 1}
                        #   )
                        # end
                        true ->
                          {start_line, start_character}
                      end

                    if (start_line < line or (start_line == line and start_character <= character)) and
                         (end_line > line or (end_line == line and end_character >= character)) do
                      {ast,
                       {[range(start_line, start_character, end_line, end_character) | acc],
                        [ast | parent_ast]}}
                    else
                      {ast, {acc, [ast | parent_ast]}}
                    end

                  other, {acc, parent_ast} ->
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

          _ ->
            [full_file_range]
        end

      surround_context_ranges =
        [full_file_range] ++
          case Code.Fragment.surround_context(text, {line + 1, character + 1}) do
            :none ->
              []

            %{begin: {start_line, start_character}, end: {end_line, end_character}} ->
              [range(start_line - 1, start_character - 1, end_line - 1, end_character - 1)]
          end

      merged_ranges =
        token_pair_ranges
        |> merge_ranges_lists(cell_pair_ranges)
        |> merge_ranges_lists(special_token_group_ranges)
        |> merge_ranges_lists(comment_block_ranges)
        |> merge_ranges_lists(surround_context_ranges)
        |> merge_ranges_lists(ast_ranges)

      if not increasingly_narrowing?(merged_ranges) do
        raise "merged_ranges are not increasingly narrowing"
      end

      merged_ranges
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
  end

  # this function differs from the one in SourceFile - it returns utf8 ranges
  defp full_range(lines) do
    utf8_size =
      lines
      |> List.last()
      |> String.length()

    range(0, 0, Enum.count(lines) - 1, utf8_size)
  end
end
