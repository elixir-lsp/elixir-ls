import Kernel, except: [length: 1]

defmodule String do
  @typedoc """
  A UTF-8 encoded binary.

  The types `String.t()` and `binary()` are equivalent to analysis tools.
  Although, for those reading the documentation, `String.t()` implies
  it is a UTF-8 encoded binary.
  """
  @type t :: binary

  @doc """
  Returns the number of Unicode graphemes in a UTF-8 string.

  ## Examples

      iex> String.length("elixir")
      6

      iex> String.length("եոգլի")
      5

  """
  @spec length(t) :: non_neg_integer
  def length(string) when is_binary(string), do: length(string, 0)

  defp length(gcs, acc) do
    case :unicode_util.gc(gcs) do
      [_ | rest] -> length(rest, acc + 1)
      [] -> acc
      {:error, <<_, rest::bits>>} -> length(rest, acc + 1)
    end
  end
end
