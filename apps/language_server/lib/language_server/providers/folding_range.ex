defmodule ElixirLS.LanguageServer.Providers.FoldingRange do
  @moduledoc """
  A textDocument/foldingRange provider implementation.

  See specification here:
    https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#textDocument_foldingRange

  ## TODO

  - [x] Indentation pass
  - [ ] Add priorities and do a proper merge
  """

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
    #   %{"startLine" => 0, "endLine" => 3},
    #   %{"startLine" => 1, "endLine" => 2}
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
    formatted_tokens = __MODULE__.Token.format_string(text)
    {:ok, token_pair_ranges} = formatted_tokens |> __MODULE__.TokenPairs.provide_ranges()
    # {:ok, indentation_ranges} = text |> __MODULE__.Indentation.provide_ranges()
    indentation_ranges = []
    ranges = merge_ranges(token_pair_ranges ++ indentation_ranges)
    {:ok, ranges}
  end

  # Make pattern-matching easier by forcing all tuples to be 3-tuples.
  # Also convert to 0-indexing as ranges are 0-indexed.
  defp format_tokens(reversed_tokens) when is_list(reversed_tokens) do
    reversed_tokens
    # This reverses the tokens, but they come out of Tokenizer.tokenize/1
    # already reversed.
    |> Enum.reduce_while({:ok, []}, fn tuple, {:ok, acc} ->
      tuple =
        case tuple do
          {a, {b1, b2, b3}} -> {a, {b1 - 1, b2 - 1, b3}, nil}
          {a, {b1, b2, b3}, c} -> {a, {b1 - 1, b2 - 1, b3}, c}
          # raise here?
          _ -> :error
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

  defp merge_ranges(list_of_range_lists) do
    list_of_range_lists
  end
end
