# codegen: do not edit
defmodule GenLSP.TypeAlias.DefinitionLink do
  @moduledoc """
  Information about where a symbol is defined.

  Provides additional metadata over normal {@link Location location} definitions, including the range of
  the defining symbol
  """

  import SchematicV, warn: false

  @type t :: GenLSP.Structures.LocationLink.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    GenLSP.Structures.LocationLink.schematic()
  end
end
