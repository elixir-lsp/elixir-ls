# codegen: do not edit
defmodule GenLSP.TypeAlias.PrepareRenameResult do
  import Schematic, warn: false

  @type t :: GenLSP.Structures.Range.t() | map() | map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      GenLSP.Structures.Range.schematic(),
      map(%{
        {"range", :range} => GenLSP.Structures.Range.schematic(),
        {"placeholder", :placeholder} => str()
      }),
      map(%{
        {"defaultBehavior", :default_behavior} => bool()
      })
    ])
  end
end
