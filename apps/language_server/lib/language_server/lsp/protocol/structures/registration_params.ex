# codegen: do not edit
defmodule GenLSP.Structures.RegistrationParams do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * registrations
  """

  typedstruct do
    field(:registrations, list(GenLSP.Structures.Registration.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"registrations", :registrations} => list(GenLSP.Structures.Registration.schematic())
    })
  end
end
