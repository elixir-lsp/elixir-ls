# codegen: do not edit
defmodule GenLSP.Notifications.TextDocumentDidClose do
  @moduledoc """
  The document close notification is sent from the client to the server when
  the document got closed in the client. The document's truth now exists where
  the document's uri points to (e.g. if the document's uri is a file uri the
  truth now exists on disk). As with the open notification the close notification
  is about managing the document's content. Receiving a close notification
  doesn't mean that the document was open in an editor before. A close
  notification requires a previous open notification to be sent.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/didClose")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.DidCloseTextDocumentParams.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/didClose",
      jsonrpc: "2.0",
      params: GenLSP.Structures.DidCloseTextDocumentParams.schematic()
    })
  end
end
