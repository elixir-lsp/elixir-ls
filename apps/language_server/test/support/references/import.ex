defmodule ElixirSenseExample.References.Import do
  import ElixirSenseExample.References.ModuleWithDef
  import ElixirSenseExample.References.ModuleWithDefMacro

  def abc() do
    foo()
    foo_macro()
  end
end
