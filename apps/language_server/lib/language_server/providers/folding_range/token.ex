defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Token do
  @moduledoc """
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

  @doc """
  This reproduces the internals of Token.tokenize/1.
  It's helpful for debuging because it doesn't hide what went wrong.
  """
  def tokenize_debug(prefix) do
    prefix
    |> String.to_charlist()
    |> do_tokenize_1_7()
  end

  defp do_tokenize_1_7(prefix_charlist) do
    case :elixir_tokenizer.tokenize(prefix_charlist, 1, []) do
      {:ok, tokens} ->
        {:ok, tokens}

      # write it like this so I know what the parts are
      {:error, {line, column, error_prefix, token}, rest, sofar} ->
        {:error, {line, column, error_prefix, token}, rest, sofar}
    end
  end
end
