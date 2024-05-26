# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.Utils.Matcher do
  @moduledoc """
  ## Suggestion Matching
  """

  import Kernel, except: [match?: 2]

  @doc """
  Naive sequential fuzzy matching without weight and requiring first char to match.

  ## Examples

      iex> ElixirLS.Utils.Matcher.match?("map", "map")
      true

      iex> ElixirLS.Utils.Matcher.match?("map", "m")
      true

      iex> ElixirLS.Utils.Matcher.match?("map", "ma")
      true

      iex> ElixirLS.Utils.Matcher.match?("map", "mp")
      true

      iex> ElixirLS.Utils.Matcher.match?("map", "")
      true

      iex> ElixirLS.Utils.Matcher.match?("map", "ap")
      false

      iex> ElixirLS.Utils.Matcher.match?("", "")
      true

      iex> ElixirLS.Utils.Matcher.match?("chunk_by", "chub")
      true

      iex> ElixirLS.Utils.Matcher.match?("chunk_by", "chug")
      false
  """
  @spec match?(name :: String.t(), hint :: String.t()) :: boolean()
  def match?(<<name_head::utf8, _name_rest::binary>>, <<hint_head::utf8, _hint_rest::binary>>)
      when name_head != hint_head do
    false
  end

  def match?(name, hint) do
    do_match?(name, hint)
  end

  defp do_match?(<<head::utf8, name_rest::binary>>, <<head::utf8, hint_rest::binary>>) do
    do_match?(name_rest, hint_rest)
  end

  defp do_match?(
         <<_head::utf8, name_rest::binary>>,
         <<_not_head::utf8, _hint_rest::binary>> = hint
       ) do
    do_match?(name_rest, hint)
  end

  defp do_match?(_name_rest, <<>>) do
    true
  end

  defp do_match?(<<>>, <<>>) do
    true
  end

  defp do_match?(<<>>, _) do
    false
  end
end
