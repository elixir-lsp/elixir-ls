defmodule ElixirLS.LanguageServer.Providers.FoldingRange do
  @moduledoc """
  A textDocument/foldingRange provider implementation.

  See specification here:
    https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#textDocument_foldingRange
  """

  alias ElixirSense.Core.Normalized.Tokenizer

  @basic_pairs %{
    do: :end,
    "(": :")",
    "[": :"]",
    "{": :"}"
  }
  @heredoc_pairs %{
    bin_heredoc: :eol
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
    #   %{"startLine" => 0, "endLine" => 3},
    #   %{"startLine" => 1, "endLine" => 2}
    # ]
  """
  @spec provide(%{text: String.t()}) ::
          {:ok, [%{required(String.t()) => non_neg_integer()}]} | {:error, String.t()}
  def provide(%{text: text}) do
    do_provide(text)
  end

  def provide(not_a_source_file) do
    {:error, "Expected a source file, found: #{inspect(not_a_source_file)}"}
  end

  defp do_provide(text) do
    ranges =
      text
      |> Tokenizer.tokenize()
      |> format_tokens()
      |> case do
        {:ok, formatted_tokens} -> formatted_tokens |> fold_tokens_into_ranges()
        _ -> []
      end

    {:ok, ranges}
  end

  # Make pattern-matching easier by forcing all tuples to be 3-tuples
  defp format_tokens(reversed_tokens) when is_list(reversed_tokens) do
    reversed_tokens
    # This reverses the tokens, but they come out of Tokenizer.tokenize/1
    # already reversed.
    |> Enum.reduce_while({:ok, []}, fn tuple, {:ok, acc} ->
      tuple =
        case tuple do
          {a, b} -> {a, b, nil}
          {a, b, c} -> {a, b, c}
          # raise here?
          _ -> :error
        end

      if tuple == :error do
        {:halt, :error}
      else
        {:cont, {:ok, [tuple | acc]}}
      end
    end)
  end

  # Note
  # This implementation allows for the possibility of 2 ranges with the same
  # startLines but different endLines.
  # It's not clear if that case is actually a problem.
  defp fold_tokens_into_ranges(tokens) when is_list(tokens) do
    ranges_from_pairs = tokens |> pair_tokens(@basic_pairs)
    ranges_from_heredocs = tokens |> pair_tokens(@heredoc_pairs)
    ranges = ranges_from_pairs ++ ranges_from_heredocs
    ranges |> convert_to_spec_ranges()
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
      %{"startLine" => start_line, "endLine" => end_line}
    end)
  end

  defp pair_tokens(tokens, kind_map) do
    tokens
    |> do_pair_tokens([], [], kind_map)
    |> Enum.map(fn {{_, {start_line, _, _}, _}, {_, {end_line, _, _}, _}} ->
      # -1 for both because the server expects 0-indexing
      # Another -1 for end_line because the range should stop 1 short
      # e.g. both "do" and "end" should be visible when collapsed
      {start_line - 1, end_line - 2}
    end)
  end

  # A stack-based approach to match range pairs
  # Notes
  # - The returned pairs will be ordered by the line of the 2nd element.
  # - Tokenizer.tokenize/1 doesn't differentiate between successful and failed
  #   attempts to tokenize the string.
  #   This could mean the returned tokens are unbalaned.
  #   Therefore, the stack may not be empty when the base clause is hit.
  #   We're choosing to return the successfully paired tokens rather than to
  #   return an error if not all tokens could be paired.
  defp do_pair_tokens([], _stack, pairs, _kind_map), do: pairs

  defp do_pair_tokens([{start_kind, _, _} = start | tail_tokens], [], pairs, kind_map) do
    new_stack = if Map.get(kind_map, start_kind), do: [start], else: []
    do_pair_tokens(tail_tokens, new_stack, pairs, kind_map)
  end

  defp do_pair_tokens(
         [{start_kind, _, _} = start | tail_tokens],
         [{top_kind, _, _} = top | tail_stack] = stack,
         pairs,
         kind_map
       ) do
    {new_stack, new_pairs} =
      cond do
        Map.get(kind_map, top_kind) == start_kind ->
          {tail_stack, [{top, start} | pairs]}

        Map.get(kind_map, start_kind) ->
          {[start | stack], pairs}

        true ->
          {stack, pairs}
      end

    do_pair_tokens(tail_tokens, new_stack, new_pairs, kind_map)
  end
end
