defmodule ElixirSenseExample.References.LocalMacroCall do
  defmacro foo_macro(), do: :ok

  def bar(), do: foo_macro()
end
