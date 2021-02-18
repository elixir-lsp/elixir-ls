defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Line do
  @moduledoc """
  FoldingRange helpers for lines.
  """

  @type cell :: {non_neg_integer(), non_neg_integer() | nil}
  @type t :: {String.t(), cell(), String.t()}

  @spec format_string(String.t()) :: [cell()]
  def format_string(text) do
    text
    |> text_to_lines()
    |> embellish_lines_with_metadata()
  end

  @spec embellish_lines_with_metadata(String.t()) :: [String.t()]
  defp text_to_lines(text) do
    text
    |> String.trim()
    |> String.split(["\r\n", "\n", "\r"])
  end

  # If we think of the code text as a grid, this function finds the cells whose
  # columns are the start of each row (line).
  # Empty rows are represented as {row, nil}.
  # We also grab the first character for convenience elsewhere.
  @spec embellish_lines_with_metadata([String.t()]) :: [t()]
  defp embellish_lines_with_metadata(lines) do
    lines
    |> Enum.with_index()
    |> Enum.map(fn {line, row} ->
      full_length = line |> String.length()
      trimmed = line |> String.trim_leading()
      trimmed_length = trimmed |> String.length()
      first = trimmed |> String.first()

      col =
        if {full_length, trimmed_length} == {0, 0} do
          nil
        else
          full_length - trimmed_length
        end

      {line, {row, col}, first}
    end)
  end
end
