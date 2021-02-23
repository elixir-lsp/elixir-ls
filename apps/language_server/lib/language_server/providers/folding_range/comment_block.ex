defmodule ElixirLS.LanguageServer.Providers.FoldingRange.CommentBlock do
  @moduledoc """
  Code folding based on comment blocks

  Note that this implementation can create comment ranges inside heredocs.
  It's a little sloppy, but it shouldn't be very impactful.
  We'd have to merge the token and line representations of the source text to
  mitigate this issue, so we've left it as is for now.
  """

  alias ElixirLS.LanguageServer.Providers.FoldingRange
  alias ElixirLS.LanguageServer.Providers.FoldingRange.Line

  @doc """
  Provides ranges for the source text based on comment blocks.

  ## Example

  text =
    \"\"\"
    defmodule SomeModule do   # 0
      def some_function() do  # 1
        # I'm                 # 2
        # a                   # 3
        # comment block       # 4
        nil                   # 5
      end                     # 6
    end                       # 7
    \"\"\"

  {:ok, ranges} =
    text
    |> FoldingRange.convert_text_to_input()
    |> CommentBlock.provide_ranges()

  # ranges == [%{startLine: 2, endLine: 4, kind?: :comment}]
  """
  @spec provide_ranges(FoldingRange.input()) :: {:ok, [FoldingRange.t()]}
  def provide_ranges(%{lines: lines}) do
    ranges =
      lines
      |> group_comments()
      |> Enum.map(&convert_comment_group_to_range/1)

    {:ok, ranges}
  end

  @spec group_comments([Line.t()]) :: [{Line.cell(), String.t()}]
  defp group_comments(lines) do
    lines
    |> Enum.reduce([[]], fn
      {_, cell, "#"}, [[{_, "#"} | _] = head | tail] ->
        [[{cell, "#"} | head] | tail]

      {_, cell, "#"}, [[] | tail] ->
        [[{cell, "#"}] | tail]

      _, [[{_, "#"} | _] | _] = acc ->
        [[] | acc]

      _, acc ->
        acc
    end)
    |> Enum.filter(fn group -> length(group) > 1 end)
  end

  @spec group_comments([{Line.cell(), String.t()}]) :: [FoldingRange.t()]
  defp convert_comment_group_to_range(group) do
    {{{end_line, _}, _}, {{start_line, _}, _}} =
      group |> FoldingRange.Helpers.first_and_last_of_list()

    %{
      startLine: start_line,
      # We're not doing end_line - 1 on purpose.
      # It seems weird to show the first _and_ last line of a comment block.
      endLine: end_line,
      kind?: :comment
    }
  end
end
