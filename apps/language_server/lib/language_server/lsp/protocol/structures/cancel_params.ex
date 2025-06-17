# codegen: do not edit
defmodule GenLSP.Structures.CancelParams do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * id: The request id to cancel.
  """

  typedstruct do
    field(:id, integer() | String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"id", :id} => oneof([int(), str()])
    })
  end
end
