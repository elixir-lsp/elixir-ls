defmodule ElixirSenseExample.ModuleWithManyClauses do
  def sum(s \\ nil, f)
  def sum(a, nil), do: a

  def sum(a, b) do
    a + b
  end

  def sum({a, b}, x, y) do
    a + b + x + y
  end
end
