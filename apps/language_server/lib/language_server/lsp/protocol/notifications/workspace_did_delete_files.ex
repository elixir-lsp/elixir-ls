# codegen: do not edit
defmodule GenLSP.Notifications.WorkspaceDidDeleteFiles do
  @moduledoc """
  The will delete files request is sent from the client to the server before files are actually
  deleted as long as the deletion is triggered from within the client.

  @since 3.16.0

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "workspace/didDeleteFiles")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.DeleteFilesParams.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/didDeleteFiles",
      jsonrpc: "2.0",
      params: GenLSP.Structures.DeleteFilesParams.schematic()
    })
  end
end
