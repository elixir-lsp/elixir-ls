defmodule ElixirLS.Test.RenameExample do
  def main do
    a = 5
    b = ElixirLS.Test.RenameExampleB.ten()
    c = add(a, b)
    d = subtract(a, b)
    add(c, d)
  end

  defp add(a, b)
  defp add(a, b) when is_integer(a) and is_integer(b), do: a + b
  defp add(a, b) when is_binary(a) and is_binary(b), do: a <> b

  def add(a, b, c), do: a + b + c

  defp subtract(a, b), do: a - b
end
