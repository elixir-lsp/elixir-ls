# codegen: do not edit
defmodule GenLSP.Structures.DocumentFormattingClientCapabilities do
  @moduledoc """
  Client capabilities of a {@link DocumentFormattingRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether formatting supports dynamic registration.
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
