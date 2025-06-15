# codegen: do not edit
defmodule GenLSP.Requests.ClientUnregisterCapability do
  @moduledoc """
  The `client/unregisterCapability` request is sent from the server to the client to unregister a previously registered capability
  handler on the client side.

  Message Direction: serverToClient
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "client/unregisterCapability")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.UnregistrationParams.t())
  end

  @type result :: nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "client/unregisterCapability",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.UnregistrationParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      nil,
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
