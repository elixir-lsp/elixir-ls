# codegen: do not edit
defmodule GenLSP.Notifications.WorkspaceDidChangeWatchedFiles do
  @moduledoc """
  The watched files notification is sent from the client to the server when
  the client detects changes to file watched by the language client.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "workspace/didChangeWatchedFiles")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.DidChangeWatchedFilesParams.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/didChangeWatchedFiles",
      jsonrpc: "2.0",
      params: GenLSP.Structures.DidChangeWatchedFilesParams.schematic()
    })
  end
end
