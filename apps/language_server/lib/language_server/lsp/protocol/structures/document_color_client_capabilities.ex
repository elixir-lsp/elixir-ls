# codegen: do not edit
defmodule GenLSP.Structures.DocumentColorClientCapabilities do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether implementation supports dynamic registration. If this is set to `true`
    the client supports the new `DocumentColorRegistrationOptions` return value
    for the corresponding server capability as well.
  """
  
  typedstruct do
    field :dynamic_registration, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool()
    })
  end
end
