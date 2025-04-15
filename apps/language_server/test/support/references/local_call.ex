defmodule ElixirSenseExample.References.LocalCall do
  def foo(), do: :ok

  def bar(), do: foo()
end
