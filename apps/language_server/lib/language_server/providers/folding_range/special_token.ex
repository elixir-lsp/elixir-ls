defmodule ElixirLS.LanguageServer.Providers.FoldingRange.SpecialToken do
  @moduledoc """
  Code folding based on "special" tokens.

  Several tokens, like `"..."`s, define ranges all on their own.
  This module converts these tokens to ranges.
  These ranges can be either `kind?: :comment` or `kind?: :region`.
  """

  alias ElixirLS.LanguageServer.Providers.FoldingRange
  alias ElixirLS.LanguageServer.Providers.FoldingRange.Token

  @kinds [
    :bin_heredoc,
    :bin_string,
    :list_heredoc,
    :list_string,
    :sigil
  ]

  @doc """
  Provides ranges based on "special" tokens

  ## Example

      iex> alias ElixirLS.LanguageServer.Providers.FoldingRange
      iex> text = \"""
      ...> defmodule A do        # 0
      ...>   def hello() do      # 1
      ...>     "
      ...>     regular string    # 3
      ...>     "
      ...>     '
      ...>     charlist string   # 6
      ...>     '
      ...>   end                 # 8
      ...> end                   # 9
      ...> \"""
      iex> FoldingRange.convert_text_to_input(text)
      ...> |> FoldingRange.SpecialToken.provide_ranges()
      {:ok, [
        %{startLine: 5, endLine: 6, kind?: :region},
        %{startLine: 2, endLine: 3, kind?: :region},
      ]}
  """
  @spec provide_ranges([FoldingRange.input()]) :: {:ok, [FoldingRange.t()]}
  def provide_ranges(%{tokens: tokens}) do
    ranges =
      tokens
      |> group_tokens()
      |> convert_groups_to_ranges()

    {:ok, ranges}
  end

  @spec group_tokens([Token.t()]) :: [[Token.t()]]
  defp group_tokens(tokens) do
    tokens
    |> Enum.reduce([], fn
      {:identifier, _, identifier} = token, acc when identifier in [:doc, :moduledoc] ->
        [[token] | acc]

      {k, _, _} = token, [[{:identifier, _, _}] = head | tail] when k in @kinds ->
        [[token | head] | tail]

      {k, _, _} = token, acc when k in @kinds ->
        [[token] | acc]

      {:eol, _, _} = token, [[{k, _, _} | _] = head | tail] when k in @kinds ->
        [[token | head] | tail]

      _, acc ->
        acc
    end)
  end

  @spec convert_groups_to_ranges([[Token.t()]]) :: [FoldingRange.t()]
  defp convert_groups_to_ranges(groups) do
    groups
    |> Enum.map(fn group ->
      # Each group comes out of group_tokens/1 reversed
      {last, first} = FoldingRange.Helpers.first_and_last_of_list(group)
      classify_group(first, last)
    end)
    |> Enum.map(fn {start_line, end_line, kind} ->
      %{
        startLine: start_line,
        endLine: end_line - 1,
        kind?: kind
      }
    end)
    |> Enum.filter(fn range -> range.endLine > range.startLine end)
  end

  defp classify_group({kind, {start_line, _, _}, _}, {_, {end_line, _, _}, _}) do
    kind = if kind == :identifier, do: :comment, else: :region
    {start_line, end_line, kind}
  end
end
