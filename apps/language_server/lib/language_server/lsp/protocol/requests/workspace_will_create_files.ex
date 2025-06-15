# codegen: do not edit
defmodule GenLSP.Requests.WorkspaceWillCreateFiles do
  @moduledoc """
  The will create files request is sent from the client to the server before files are actually
  created as long as the creation is triggered from within the client.

  @since 3.16.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "workspace/willCreateFiles")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.CreateFilesParams.t())
  end

  @type result :: GenLSP.Structures.WorkspaceEdit.t() | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/willCreateFiles",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.CreateFilesParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([GenLSP.Structures.WorkspaceEdit.schematic(), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
