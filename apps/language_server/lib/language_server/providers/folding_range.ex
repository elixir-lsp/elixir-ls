defmodule ElixirLS.LanguageServer.Providers.FoldingRange do
  @moduledoc """
  A textDocument/foldingRange provider implementation.

  ## Background

  See specification here:

  https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#textDocument_foldingRange

  ## Methodology

  ### High level

  We make multiple passes (currently 4) through the source text and create
  folding ranges from each pass.
  Then we merge the ranges from each pass to provide the final ranges.
  Each pass gets a priority to help break ties (the priority is an integer,
  higher integers win).

  ### Indentation pass (priority: 1)

  We use the indentation level -- determined by the column of the first
  non-whitespace character on each line -- to provide baseline ranges.
  All ranges from this pass are `kind?: :region` ranges.

  ### Comment block pass (priority: 2)

  We let "comment blocks", consecutive lines starting with `#`, from regions.
  All ranges from this pass are `kind?: :comment` ranges.

  ### Token-pairs pass (priority: 3)

  We use pairs of tokens, e.g. `do` and `end`, to provide another pass of
  ranges.
  All ranges from this pass are `kind?: :region` ranges.

  ### Special tokens pass (priority: 3)

  We find strings (regular/charlist strings/heredocs) and sigils in a pass as
  they're delimited by a few special tokens.
  Ranges from this pass are either
  - `kind?: :comment` if the token is paired with `@doc` or `@moduledoc`, or
  - `kind?: :region` otherwise.

  ## Notes

  Each pass may return ranges in any order.
  But all ranges are valid, i.e. endLine > startLine.
  """

  alias __MODULE__

  @type input :: %{
          tokens: [FoldingRange.Token.t()],
          lines: [FoldingRange.Line.t()]
        }

  @type t :: %{
          required(:startLine) => non_neg_integer(),
          required(:endLine) => non_neg_integer(),
          optional(:startCharacter?) => non_neg_integer(),
          optional(:endCharacter?) => non_neg_integer(),
          optional(:kind?) => :comment | :imports | :region
        }

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
        %{startLine: 0, endLine: 3, kind?: :region},
        %{startLine: 1, endLine: 2, kind?: :region}
      ]}

  """
  @spec provide(%{text: String.t()}) :: {:ok, [t()]}
  def provide(%{text: text}) do
    do_provide(text)
  end

  defp do_provide(text) do
    input = convert_text_to_input(text)

    passes_with_priority = [
      {1, FoldingRange.Indentation},
      {2, FoldingRange.CommentBlock},
      {3, FoldingRange.TokenPair},
      {3, FoldingRange.SpecialToken}
    ]

    ranges =
      passes_with_priority
      |> Enum.map(fn {priority, pass} ->
        ranges = ranges_from_pass(pass, input)
        {priority, ranges}
      end)
      |> merge_ranges_with_priorities()

    {:ok, ranges}
  end

  def convert_text_to_input(text) do
    %{
      tokens: FoldingRange.Token.format_string(text),
      lines: FoldingRange.Line.format_string(text)
    }
  end

  defp ranges_from_pass(pass, input) do
    with {:ok, ranges} <- pass.provide_ranges(input) do
      ranges
    else
      _ -> []
    end
  end

  defp merge_ranges_with_priorities(range_lists_with_priorities) do
    range_lists_with_priorities
    |> Enum.flat_map(fn {priority, ranges} -> Enum.zip(Stream.cycle([priority]), ranges) end)
    |> Enum.group_by(fn {_priority, range} -> range.startLine end)
    |> Enum.map(fn {_start, ranges_with_priority} ->
      {_priority, range} =
        ranges_with_priority
        |> Enum.max_by(fn {priority, range} -> {priority, range.endLine} end)

      range
    end)
    |> Enum.sort_by(& &1.startLine)
  end
end
