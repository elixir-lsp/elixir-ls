# codegen: do not edit
defmodule GenLSP.Structures.DidChangeConfigurationRegistrationOptions do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * section
  """

  typedstruct do
    field(:section, String.t() | list(String.t()))
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"section", :section}) => oneof([str(), list(str())])
    })
  end
end
