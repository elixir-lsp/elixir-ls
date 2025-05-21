defmodule ElixirSenseExample.References.Captures do
  import ElixirSenseExample.References.ModuleWithDef
  alias ElixirSenseExample.References.ModuleWithDef, as: M
  def abc(), do: :ok

  def foo(x) do
    [&abc/0, &M.foo/0, &foo/0]
  end
end
