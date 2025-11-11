defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Token do
  @moduledoc """
  This module normalizes the tokens provided by

    `ElixirSense.Core.Normalized.Tokenizer`
  """

  alias ElixirSense.Core.Normalized.Tokenizer

  @type t :: {atom(), {non_neg_integer(), non_neg_integer(), any()}, any()}

  @doc """
  Make pattern-matching easier by forcing all token tuples to be 3-tuples.
  Also convert start_info to 0-indexing as ranges are 0-indexed.
  """
  @spec format_string(String.t()) :: [t()]
  def format_string(text) do
    reversed_tokens = text |> Tokenizer.tokenize()

    reversed_tokens
    # This reverses the tokens, but they come out of Tokenizer.tokenize/1
    # already reversed.
    |> Enum.reduce([], fn tuple, acc ->
      tuple =
        case tuple do
          {a, {b1, b2, b3}} ->
            {a, {b1 - 1, b2 - 1, b3}, nil}

          {a, {b1, b2, b3}, c} ->
            {a, {b1 - 1, b2 - 1, b3}, c}

          # Handle 'not in' operator token format from Elixir 1.19+
          # {:in_op, {start_line, start_col, nil}, :"not in", {end_line, end_col, nil}}
          {:in_op, {b1, b2, b3}, :"not in", {_d1, _d2, _d3}} ->
            {:in_op, {b1 - 1, b2 - 1, b3}, :"not in"}

          {:sigil, {b1, b2, b3}, _, _, _, _, delimiter} ->
            {:sigil, {b1 - 1, b2 - 1, b3}, delimiter}

          {:bin_heredoc, {b1, b2, b3}, _, _} ->
            {:bin_heredoc, {b1 - 1, b2 - 1, b3}, nil}

          {:list_heredoc, {b1, b2, b3}, _, _} ->
            {:list_heredoc, {b1 - 1, b2 - 1, b3}, nil}
        end

      [tuple | acc]
    end)
  end
end
