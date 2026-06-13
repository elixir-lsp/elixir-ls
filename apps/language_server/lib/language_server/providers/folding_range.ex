defmodule ElixirLS.LanguageServer.Providers.FoldingRange do
  @moduledoc """
  A textDocument/foldingRange provider implementation.

  ## Background

  See specification here:

  https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#textDocument_foldingRange

  ## Methodology

  ### High level

  We make multiple passes through the source text and create folding ranges from
  each pass, then merge them. Each pass gets a priority to break ties (higher
  wins); when two passes produce a range with the same start line, the
  higher-priority (and then longer) range is kept.

  ### Indentation pass (priority: 1)

  We use the indentation level -- determined by the column of the first
  non-whitespace character on each line -- to provide baseline ranges (e.g.
  multi-line assignments and clause bodies that have no single closing token).
  All ranges from this pass are `kind: "region"` ranges.

  ### Comment block pass (priority: 2)

  Consecutive full-line comments (from `Toxic2.string_to_quoted_with_comments`)
  form `kind: "comment"` ranges. Comments inside strings/heredocs are correctly
  ignored because they come from the parser, not a line scan.

  ### AST region pass (priority: 3)

  We fold the source ranges of the error-tolerant toxic2 AST nodes
  (`range: true`): `do`/`end` blocks, delimited containers/calls
  (`()`/`[]`/`{}`/`<<>>`/`fn`), and strings/heredocs/sigils. A string argument of
  `@doc`/`@moduledoc`/`@typedoc`/`@shortdoc` folds as `kind: "comment"`; the rest
  are `kind: "region"`. This replaces the previous token-pair and special-token
  passes.

  ## Notes

  All ranges are valid, i.e. end_line > start_line.
  """

  alias __MODULE__

  @type input :: %{
          tokens: [FoldingRange.Token.t()],
          lines: [FoldingRange.Line.t()]
        }

  @type t :: GenLSP.Structures.FoldingRange.t()

  @doc """
  Provides folding ranges for a source file

  ## Example

      iex> alias ElixirLS.LanguageServer.Providers.FoldingRange
      iex> text = \"""
      ...> defmodule A do    # 0
      ...>   def hello() do  # 1
      ...>     :world        # 2
      ...>   end             # 3
      ...> end               # 4
      ...> \"""
      iex> FoldingRange.provide(%{text: text})
      {:ok, [
        %GenLSP.Structures.FoldingRange{start_line: 0, end_line: 3, kind: "region"},
        %GenLSP.Structures.FoldingRange{start_line: 1, end_line: 2, kind: "region"}
      ]}

  """
  @spec provide(%{text: String.t()}) :: {:ok, [t()]}
  def provide(%{text: text}) do
    do_provide(text)
  end

  defp do_provide(text) do
    # The structural (do/end, delimiters, heredocs) and comment ranges come from the error-tolerant
    # toxic2 parser - node source ranges (`range: true`) replace the old token-pair/special-token
    # passes, and comments come from `Toxic2.string_to_quoted_with_comments`. The indentation pass
    # stays (it is pure line analysis and provides the assignment / clause folds that have no single
    # closing token). Priorities mirror the original: AST regions (3) override indentation (1) at a
    # shared start line, exactly as the token-pair pass used to.
    {ast, diagnostics, comments} =
      Toxic2.string_to_quoted_with_comments(text,
        token_metadata: true,
        range: true,
        literal_encoder: fn literal, meta -> {:ok, {:__block__, meta, [literal]}} end
      )

    lines = FoldingRange.Line.format_string(text)

    passes_with_priority = [
      {1, indentation_ranges(lines)},
      {2, comment_ranges(comments)},
      {3, ast_ranges(ElixirSense.Core.Parser.neutralize_errors(ast, diagnostics, true))}
    ]

    ranges = merge_ranges_with_priorities(passes_with_priority)

    {:ok, ranges}
  end

  def convert_text_to_input(text) do
    %{
      tokens: FoldingRange.Token.format_string(text),
      lines: FoldingRange.Line.format_string(text)
    }
  end

  defp indentation_ranges(lines) do
    # Indentation only reads `:lines`, but its spec takes the full input map; pass empty tokens
    # rather than run the (unused) tokenizer.
    {:ok, ranges} = FoldingRange.Indentation.provide_ranges(%{tokens: [], lines: lines})
    ranges
  end

  # --- comment-block folds (from toxic2 comments) ------------------------

  # Group contiguous full-line comments (inline comments have previous_eol_count 0; a blank line
  # between comments, previous_eol_count >= 2, splits the block) and fold each multi-line block.
  defp comment_ranges(comments) do
    comments
    |> Enum.filter(&(&1.previous_eol_count > 0))
    |> Enum.reduce([], fn comment, groups ->
      line = comment.line - 1

      case groups do
        [[previous | _] = group | rest]
        when comment.previous_eol_count == 1 and line == previous + 1 ->
          [[line | group] | rest]

        _ ->
          [[line] | groups]
      end
    end)
    |> Enum.flat_map(fn lines ->
      last_line = hd(lines)
      first_line = List.last(lines)

      if last_line > first_line do
        [
          %GenLSP.Structures.FoldingRange{
            start_line: first_line,
            end_line: last_line,
            kind: "comment"
          }
        ]
      else
        []
      end
    end)
  end

  # --- structural folds (from toxic2 AST node ranges) --------------------

  @doc_attributes [:doc, :moduledoc, :typedoc, :shortdoc]

  defp ast_ranges(ast) do
    {_ast, {ranges, _doc_ranges}} =
      Macro.prewalk(ast, {[], MapSet.new()}, fn node, {ranges, doc_ranges} ->
        doc_ranges = collect_doc_string(node, doc_ranges)

        ranges =
          case fold_for(node) do
            {start_line, end_line, range} when end_line > start_line ->
              kind = if MapSet.member?(doc_ranges, range), do: "comment", else: "region"

              [
                %GenLSP.Structures.FoldingRange{
                  start_line: start_line,
                  end_line: end_line,
                  kind: kind
                }
                | ranges
              ]

            _ ->
              ranges
          end

        {node, {ranges, doc_ranges}}
      end)

    ranges
  end

  # `@doc`/`@moduledoc`/... with a string/heredoc argument: remember that string's range so its fold
  # is marked `:comment` rather than `:region` (matching the old special-token pass).
  defp collect_doc_string({:@, _, [{attr, _, [arg]}]}, doc_ranges) when attr in @doc_attributes do
    case string_range(arg) do
      nil -> doc_ranges
      range -> MapSet.put(doc_ranges, range)
    end
  end

  defp collect_doc_string(_node, doc_ranges), do: doc_ranges

  defp string_range({_form, meta, _args}) when is_list(meta) do
    if Keyword.has_key?(meta, :delimiter), do: Keyword.get(meta, :range)
  end

  defp string_range(_node), do: nil

  # A fold for a node spans from its start line to the last line that stays visible when collapsed:
  # the line before a closing `end`/`)`/`]`/`}`/`>>` or heredoc terminator. Only do/end blocks,
  # delimited containers/calls, and strings/heredocs fold here; everything else (assignments, clause
  # bodies, pipelines) is left to the indentation pass, which mirrors the original behavior.
  defp fold_for({_form, meta, _args}) when is_list(meta) do
    case Keyword.get(meta, :range) do
      {{start_line, _}, {end_line, _}} = range ->
        case fold_end_line(meta, end_line) do
          nil -> nil
          fold_end -> {start_line - 1, fold_end, range}
        end

      _ ->
        nil
    end
  end

  defp fold_for(_node), do: nil

  defp fold_end_line(meta, range_end_line) do
    cond do
      line = keyword_line(meta, :end) -> line - 2
      line = keyword_line(meta, :closing) -> line - 2
      Keyword.has_key?(meta, :delimiter) -> range_end_line - 2
      true -> nil
    end
  end

  defp keyword_line(meta, key) do
    case Keyword.get(meta, key) do
      sub when is_list(sub) -> Keyword.get(sub, :line)
      _ -> nil
    end
  end

  defp merge_ranges_with_priorities(range_lists_with_priorities) do
    range_lists_with_priorities
    |> Enum.flat_map(fn {priority, ranges} -> Enum.zip(Stream.cycle([priority]), ranges) end)
    |> Enum.group_by(fn {_priority, range} -> range.start_line end)
    |> Enum.map(fn {_start, ranges_with_priority} ->
      {_priority, range} =
        ranges_with_priority
        |> Enum.max_by(fn {priority, range} -> {priority, range.end_line} end)

      range
    end)
    |> Enum.sort_by(& &1.start_line)
  end
end
