# codegen: do not edit
defmodule GenLSP.Structures.DefinitionClientCapabilities do
  @moduledoc """
  Client Capabilities for a {@link DefinitionRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether definition supports dynamic registration.
  * link_support: The client supports additional metadata in the form of definition links.

    @since 3.14.0
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:link_support, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"linkSupport", :link_support}) => bool()
    })
  end
end
