defmodule ElixirLS.LanguageServer.Providers.FoldingRange do
  @moduledoc """
  A textDocument/foldingRange provider implementation.

  See specification here:
    https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#textDocument_foldingRange
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

    text = \"\"\"
    defmodule A do    # 0
      def hello() do  # 1
        :world        # 2
      end             # 3
    end               # 4
    \"\"\"

    {:ok, ranges} = FoldingRange.provide(%{text: text})

    ranges
    # [
    #   %{startLine: 0, endLine: 3},
    #   %{startLine: 1, endLine: 2}
    # ]
  """
  @spec provide(%{text: String.t()}) :: {:ok, [t()]} | {:error, String.t()}
  def provide(%{text: text}) do
    do_provide(text)
  end

  def provide(not_a_source_file) do
    {:error, "Expected a source file, found: #{inspect(not_a_source_file)}"}
  end

  defp do_provide(text) do
    input = convert_text_to_input(text)
    {:ok, token_pair_ranges} = input |> FoldingRange.TokenPairs.provide_ranges()
    {:ok, indentation_ranges} = input |> FoldingRange.Indentation.provide_ranges()
    {:ok, heredoc_ranges} = input |> FoldingRange.Heredoc.provide_ranges()
    {:ok, comment_block_ranges} = input |> FoldingRange.CommentBlock.provide_ranges()

    ranges =
      merge_ranges_with_priorities([
        {1, indentation_ranges},
        {2, comment_block_ranges},
        {3, token_pair_ranges},
        {3, heredoc_ranges}
      ])

    {:ok, ranges}
  end

  def convert_text_to_input(text) do
    %{
      tokens: FoldingRange.Token.format_string(text),
      lines: FoldingRange.Line.format_string(text)
    }
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
