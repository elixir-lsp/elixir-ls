defmodule ElixirSenseExample.References.RequireAs do
  require ElixirSenseExample.References.ModuleWithDefMacro, as: M

  def abc() do
    M.foo_macro()
  end
end
