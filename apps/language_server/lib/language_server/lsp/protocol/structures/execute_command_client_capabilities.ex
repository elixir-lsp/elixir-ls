# codegen: do not edit
defmodule GenLSP.Structures.ExecuteCommandClientCapabilities do
  @moduledoc """
  The client capabilities of a {@link ExecuteCommandRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Execute command supports dynamic registration.
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
