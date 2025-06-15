# codegen: do not edit
defmodule GenLSP.Notifications.WorkspaceDidCreateFiles do
  @moduledoc """
  The did create files notification is sent from the client to the server when
  files were created from within the client.

  @since 3.16.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "workspace/didCreateFiles")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.CreateFilesParams.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/didCreateFiles",
      jsonrpc: "2.0",
      params: GenLSP.Structures.CreateFilesParams.schematic()
    })
  end
end
