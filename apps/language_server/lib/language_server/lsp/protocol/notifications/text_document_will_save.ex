# codegen: do not edit
defmodule GenLSP.Notifications.TextDocumentWillSave do
  @moduledoc """
  A document will save notification is sent from the client to the server before
  the document is actually saved.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/willSave")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.WillSaveTextDocumentParams.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/willSave",
      jsonrpc: "2.0",
      params: GenLSP.Structures.WillSaveTextDocumentParams.schematic()
    })
  end
end
