# codegen: do not edit
defmodule GenLSP.Notifications.DollarCancelRequest do
  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "$/cancelRequest")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.CancelParams.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "$/cancelRequest",
      jsonrpc: "2.0",
      params: GenLSP.Structures.CancelParams.schematic()
    })
  end
end
