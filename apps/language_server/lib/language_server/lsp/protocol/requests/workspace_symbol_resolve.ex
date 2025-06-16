# codegen: do not edit
defmodule GenLSP.Requests.WorkspaceSymbolResolve do
  @moduledoc """
  A request to resolve the range inside the workspace
  symbol's location.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "workspaceSymbol/resolve")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.WorkspaceSymbol.t())
  end

  @type result :: GenLSP.Structures.WorkspaceSymbol.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspaceSymbol/resolve",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.WorkspaceSymbol.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      GenLSP.Structures.WorkspaceSymbol.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
