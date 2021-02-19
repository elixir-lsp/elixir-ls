defmodule ElixirLS.LanguageServer.Providers.FoldingRange.TokenPairs do
  @moduledoc """
  """

  alias ElixirLS.LanguageServer.Providers.FoldingRange

  @token_pairs %{
    "(": [:")"],
    "[": [:"]"],
    "{": [:"}"],
    # do blocks
    do: [:block_identifier, :end],
    block_identifier: [:block_identifier, :end],
    # other special forms
    with: [:do],
    for: [:do],
    case: [:do],
    fn: [:end]
  }

  # Note
  # This implementation allows for the possibility of 2 ranges with the same
  # startLines but different endLines.
  # It's not clear if that case is actually a problem.
  @spec provide_ranges([FoldingRange.input()]) :: {:ok, [FoldingRange.t()]}
  def provide_ranges(%{tokens: tokens}) do
    ranges =
      tokens
      |> pair_tokens()
      |> convert_to_spec_ranges()

    {:ok, ranges}
  end

  defp pair_tokens(tokens) do
    tokens
    |> do_pair_tokens([], [])
    |> Enum.map(fn {{_, {start_line, _, _}, _}, {_, {end_line, _, _}, _}} ->
      # -1 for end_line because the range should stop 1 short
      # e.g. both "do" and "end" should be visible when collapsed
      {start_line, end_line - 1}
    end)
  end

  # A stack-based approach to match range pairs
  # Notes
  # - The returned pairs will be ordered by the line of the 2nd element.
  # - Tokenizer.tokenize/1 doesn't differentiate between successful and failed
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

  defp convert_to_spec_ranges(ranges) do
    ranges
    |> Enum.filter(fn {start_line, end_line} -> end_line > start_line end)
    |> Enum.sort()
    |> Enum.dedup()
    ## Remove the above sort + dedup lines and uncomment the following if no
    ## two ranges may share a startLine
    # |> Enum.group_by(fn {start_line, _} -> start_line end)
    # |> Enum.map(fn {_, ranges} ->
    #   Enum.max_by(ranges, fn {_, end_line} -> end_line end)
    # end)
    |> Enum.map(fn {start_line, end_line} ->
      %{startLine: start_line, endLine: end_line, kind?: :region}
    end)
  end
end
