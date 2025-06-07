# codegen: do not edit
defmodule GenLSP.Notifications.WorkspaceDidRenameFiles do
  @moduledoc """
  The did rename files notification is sent from the client to the server when
  files were renamed from within the client.

  @since 3.16.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "workspace/didRenameFiles"
    field :jsonrpc, String.t(), default: "2.0"
    field :params, GenLSP.Structures.RenameFilesParams.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/didRenameFiles",
      jsonrpc: "2.0",
      params: GenLSP.Structures.RenameFilesParams.schematic()
    })
  end
end
