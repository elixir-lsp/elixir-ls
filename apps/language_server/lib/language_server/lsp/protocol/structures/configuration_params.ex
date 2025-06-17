# codegen: do not edit
defmodule GenLSP.Structures.ConfigurationParams do
  @moduledoc """
  The parameters of a configuration request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * items
  """

  typedstruct do
    field(:items, list(GenLSP.Structures.ConfigurationItem.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"items", :items} => list(GenLSP.Structures.ConfigurationItem.schematic())
    })
  end
end
