# codegen: do not edit
defmodule GenLSP.Structures.UnregistrationParams do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * unregisterations
  """

  typedstruct do
    field(:unregisterations, list(GenLSP.Structures.Unregistration.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"unregisterations", :unregisterations} =>
        list(GenLSP.Structures.Unregistration.schematic())
    })
  end
end
