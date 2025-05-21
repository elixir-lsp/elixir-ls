defmodule ElixirSenseExample.References.Alias do
  alias ElixirSenseExample.References.ModuleWithDef

  def abc() do
    ModuleWithDef.foo()
  end
end
