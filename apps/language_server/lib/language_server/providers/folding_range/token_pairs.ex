defmodule ElixirLS.LanguageServer.Providers.FoldingRange.TokenPair do
  @moduledoc """
  Code folding based on pairs of tokens

  Certain pairs of tokens, like `do` and `end`, natrually define ranges.
  These ranges all have `kind?: :region`.

  Note that we exclude the line that the 2nd of the pair, e.g. `end`, is on.
  This is so that when collapsed, both tokens are visible.
  """

  alias ElixirLS.LanguageServer.Providers.FoldingRange
  alias ElixirLS.LanguageServer.Providers.FoldingRange.Token

  @token_pairs %{
    "(": [:")"],
    "[": [:"]"],
    "{": [:"}"],
    "<<": [:">>"],
    # do blocks
    do: [:block_identifier, :end],
    block_identifier: [:block_identifier, :end],
    # other special forms that are not covered by :block_identifier
    with: [:do],
    for: [:do],
    case: [:do],
    fn: [:end]
  }

  @doc """
  Provides ranges based on token pairs

  ## Example

      iex> alias ElixirLS.LanguageServer.Providers.FoldingRange
      iex> text = \"""
      ...>   defmodule Module do       # 0
      ...>     def some_function() do  # 1
      ...>       4                     # 2
      ...>     end                     # 3
      ...>   end                       # 4
      ...>   \"""
      iex> FoldingRange.convert_text_to_input(text)
      ...> |> TokenPair.provide_ranges()
      {:ok, [
        %{startLine: 0, endLine: 3, kind?: :region},
        %{startLine: 1, endLine: 2, kind?: :region}
      ]}
  """
  @spec provide_ranges([FoldingRange.input()]) :: {:ok, [FoldingRange.t()]}
  def provide_ranges(%{tokens: tokens}) do
    ranges =
      tokens
      |> pair_tokens()
      |> convert_token_pairs_to_ranges()

    {:ok, ranges}
  end

  @spec pair_tokens([Token.t()]) :: [{Token.t(), Token.t()}]
  defp pair_tokens(tokens) do
    do_pair_tokens(tokens, [], [])
  end

  # Note
  #   Tokenizer.tokenize/1 doesn't differentiate between successful and failed
  #   attempts to tokenize the string.
  #   This could mean the returned tokens are unbalanced.
  #   Therefore, the stack may not be empty when the base clause is hit.
  #   We're choosing to return the successfully paired tokens rather than to
  #   return an error if not all tokens could be paired.
  defp do_pair_tokens([], _stack, pairs), do: pairs

  defp do_pair_tokens([{head_kind, _, _} = head | tail_tokens], [], pairs) do
    new_stack = if @token_pairs |> Map.has_key?(head_kind), do: [head], else: []
    do_pair_tokens(tail_tokens, new_stack, pairs)
  end

  defp do_pair_tokens(
         [{head_kind, _, _} = head | tail_tokens],
         [{top_kind, _, _} = top | tail_stack] = stack,
         pairs
       ) do
    head_matches_any? = @token_pairs |> Map.has_key?(head_kind)
    # Map.get/2 will always succeed because we only push matches to the stack.
    head_matches_top? = @token_pairs |> Map.get(top_kind) |> Enum.member?(head_kind)

    {new_stack, new_pairs} =
      case {head_matches_any?, head_matches_top?} do
        {false, false} -> {stack, pairs}
        {false, true} -> {tail_stack, [{top, head} | pairs]}
        {true, false} -> {[head | stack], pairs}
        {true, true} -> {[head | tail_stack], [{top, head} | pairs]}
      end

    do_pair_tokens(tail_tokens, new_stack, new_pairs)
  end

  @spec convert_token_pairs_to_ranges([{Token.t(), Token.t()}]) :: [FoldingRange.t()]
  defp convert_token_pairs_to_ranges(token_pairs) do
    token_pairs
    |> Enum.map(fn {{_, {start_line, _, _}, _}, {_, {end_line, _, _}, _}} ->
      # -1 for end_line because the range should stop 1 short
      # e.g. both "do" and "end" should be visible when collapsed
      {start_line, end_line - 1}
    end)
    |> Enum.filter(fn {start_line, end_line} -> end_line > start_line end)
    |> Enum.map(fn {start_line, end_line} ->
      %{startLine: start_line, endLine: end_line, kind?: :region}
    end)
  end
end
