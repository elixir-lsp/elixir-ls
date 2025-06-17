# codegen: do not edit
defmodule GenLSP.Structures.ConfigurationItem do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * scope_uri: The scope to get the configuration section for.
  * section: The configuration section asked for.
  """

  typedstruct do
    field(:scope_uri, String.t())
    field(:section, String.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"scopeUri", :scope_uri}) => str(),
      optional({"section", :section}) => str()
    })
  end
end
