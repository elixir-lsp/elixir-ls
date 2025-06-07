# codegen: do not edit
defmodule GenLSP.Requests.Initialize do
  @moduledoc """
  The initialize request is sent from the client to the server.
  It is sent once as the request after starting up the server.
  The requests parameter is of type {@link InitializeParams}
  the response if of type {@link InitializeResult} of a Thenable that
  resolves to such.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "initialize"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.InitializeParams.t()
  end

  @type result :: GenLSP.Structures.InitializeResult.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "initialize",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.InitializeParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      GenLSP.Structures.InitializeResult.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
