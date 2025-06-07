# codegen: do not edit
defmodule GenLSP.Requests.WindowWorkDoneProgressCreate do
  @moduledoc """
  The `window/workDoneProgress/create` request is sent from the server to the client to initiate progress
  reporting from the server.

  Message Direction: serverToClient
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "window/workDoneProgress/create"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.WorkDoneProgressCreateParams.t()
  end

  @type result :: nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "window/workDoneProgress/create",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.WorkDoneProgressCreateParams.schematic()
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
