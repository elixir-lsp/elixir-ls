# codegen: do not edit
defmodule GenLSP.TypeAlias.ProgressToken do
  import SchematicV, warn: false

  @type t :: integer() | String.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([int(), str()])
  end
end
