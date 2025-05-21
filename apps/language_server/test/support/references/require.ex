defmodule ElixirSenseExample.References.Require do
  require ElixirSenseExample.References.ModuleWithDefMacro

  def abc() do
    ElixirSenseExample.References.ModuleWithDefMacro.foo_macro()
  end
end
