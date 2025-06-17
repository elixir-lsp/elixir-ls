# codegen: do not edit
defmodule GenLSP.Structures.DocumentHighlightClientCapabilities do
  @moduledoc """
  Client Capabilities for a {@link DocumentHighlightRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether document highlight supports dynamic registration.
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
