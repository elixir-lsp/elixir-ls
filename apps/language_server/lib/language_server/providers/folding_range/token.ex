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
    |> Enum.reduce_while({:ok, []}, fn tuple, {:ok, acc} ->
      tuple =
        case tuple do
          {a, {b1, b2, b3}} ->
            {a, {b1 - 1, b2 - 1, b3}, nil}

          {a, {b1, b2, b3}, c} ->
            {a, {b1 - 1, b2 - 1, b3}, c}

          {:sigil, {b1, b2, b3}, _, _, _, _, delimiter} ->
            {:sigil, {b1 - 1, b2 - 1, b3}, delimiter}

          # Older versions of Tokenizer.tokenize/1
          {:sigil, {b1, b2, b3}, _, _, _, delimiter} ->
            {:sigil, {b1 - 1, b2 - 1, b3}, delimiter}

          # raise here?
          _ ->
            :error
        end

      if tuple == :error do
        {:halt, :error}
      else
        {:cont, {:ok, [tuple | acc]}}
      end
    end)
    |> case do
      {:ok, formatted_tokens} -> formatted_tokens
      _ -> []
    end
  end
end
