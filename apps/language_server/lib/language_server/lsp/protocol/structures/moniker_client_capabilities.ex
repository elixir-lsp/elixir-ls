# codegen: do not edit
defmodule GenLSP.Structures.MonikerClientCapabilities do
  @moduledoc """
  Client capabilities specific to the moniker request.

  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether moniker supports dynamic registration. If this is set to `true`
    the client supports the new `MonikerRegistrationOptions` return value
    for the corresponding server capability as well.
  """

  typedstruct do
    field(:dynamic_registration, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool()
    })
  end
end
