defmodule ElixirLS.Test.RenameExample do
  def main do
    a = 5
    b = 10
    c = add(a, b)
    d = subtract(a, b)
    add(c, d)
  end

  defp add(a, b)
  defp add(a, b) when is_integer(a) and is_integer(b), do: a + b
  defp add(a, b) when is_binary(a) and is_binary(b), do: a <> b

  defp subtract(a, b), do: a - b
end
