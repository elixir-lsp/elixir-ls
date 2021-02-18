defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Heredoc do
  @moduledoc """
  """

  alias ElixirLS.LanguageServer.Providers.FoldingRange

  @spec provide_ranges([FoldingRange.input()]) :: {:ok, [FoldingRange.t()]}
  def provide_ranges(%{tokens: tokens}) do
    ranges =
      tokens
      |> group_heredoc_tokens()
      |> convert_heredoc_groups_to_ranges()

    {:ok, ranges}
  end

  # The :bin_heredoc token will be either
  #   - by itself or
  #   - directly after an :identifier (either :doc or :moduledoc).
  # :bin_heredoc regions are ended by an :eol token.
  defp group_heredoc_tokens(tokens) do
    tokens
    |> Enum.reduce([], fn
      {:identifier, _, x} = token, acc when x in [:doc, :moduledoc] ->
        [[token] | acc]

      {:bin_heredoc, _, _} = token, [[{:identifier, _, _}] = head | tail] ->
        [[token | head] | tail]

      {:bin_heredoc, _, _} = token, acc ->
        [[token] | acc]

      {:eol, _, _} = token, [[{:bin_heredoc, _, _} | _] = head | tail] ->
        [[token | head] | tail]

      _, acc ->
        acc
    end)
  end

  defp convert_heredoc_groups_to_ranges(heredoc_groups) do
    heredoc_groups
    |> Enum.map(fn group ->
      # Each group comes out of group_heredoc_tokens/1 reversed
      {last, first} = FoldingRange.Helpers.first_and_last_of_list(group)
      classify_group(first, last)
    end)
  end

  defp classify_group({:bin_heredoc, {start_line, _, _}, _}, {_, {end_line, _, _}, _}) do
    %{startLine: start_line, endLine: end_line - 1, kind?: :region}
  end

  defp classify_group({:identifier, {start_line, _, _}, _}, {_, {end_line, _, _}, _}) do
    %{startLine: start_line, endLine: end_line - 1, kind?: :comment}
  end
end
