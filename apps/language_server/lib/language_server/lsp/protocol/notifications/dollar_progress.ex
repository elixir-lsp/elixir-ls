# codegen: do not edit
defmodule GenLSP.Notifications.DollarProgress do
  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "$/progress"
    field :jsonrpc, String.t(), default: "2.0"
    field :params, GenLSP.Structures.ProgressParams.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "$/progress",
      jsonrpc: "2.0",
      params: GenLSP.Structures.ProgressParams.schematic()
    })
  end
end
