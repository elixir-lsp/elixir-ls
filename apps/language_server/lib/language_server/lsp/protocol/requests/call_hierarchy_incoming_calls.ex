# codegen: do not edit
defmodule GenLSP.Requests.CallHierarchyIncomingCalls do
  @moduledoc """
  A request to resolve the incoming calls for a given `CallHierarchyItem`.

  @since 3.16.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "callHierarchy/incomingCalls"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.CallHierarchyIncomingCallsParams.t()
  end

  @type result :: list(GenLSP.Structures.CallHierarchyIncomingCall.t()) | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "callHierarchy/incomingCalls",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.CallHierarchyIncomingCallsParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([list(GenLSP.Structures.CallHierarchyIncomingCall.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
