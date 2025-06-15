# codegen: do not edit
defmodule GenLSP.Notifications.DollarLogTrace do
  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "$/logTrace")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.LogTraceParams.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "$/logTrace",
      jsonrpc: "2.0",
      params: GenLSP.Structures.LogTraceParams.schematic()
    })
  end
end
