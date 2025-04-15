defmodule ElixirSenseExample.References.Super do
  use ElixirSenseExample.OverridableFunctions
  def test(_x, y), do: super(&super/2, y + 1)
end
