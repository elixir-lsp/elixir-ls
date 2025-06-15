# codegen: do not edit
defmodule GenLSP.Structures.TypeDefinitionClientCapabilities do
  @moduledoc """
  Since 3.6.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether implementation supports dynamic registration. If this is set to `true`
    the client supports the new `TypeDefinitionRegistrationOptions` return value
    for the corresponding server capability as well.
  * link_support: The client supports additional metadata in the form of definition links.

    Since 3.14.0
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:link_support, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"linkSupport", :link_support}) => bool()
    })
  end
end
