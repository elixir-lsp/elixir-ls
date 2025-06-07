# codegen: do not edit
defmodule GenLSP.Notifications.TextDocumentDidOpen do
  @moduledoc """
  The document open notification is sent from the client to the server to signal
  newly opened text documents. The document's truth is now managed by the client
  and the server must not try to read the document's truth using the document's
  uri. Open in this sense means it is managed by the client. It doesn't necessarily
  mean that its content is presented in an editor. An open notification must not
  be sent more than once without a corresponding close notification send before.
  This means open and close notification must be balanced and the max open count
  is one.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "textDocument/didOpen"
    field :jsonrpc, String.t(), default: "2.0"
    field :params, GenLSP.Structures.DidOpenTextDocumentParams.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: GenLSP.Structures.DidOpenTextDocumentParams.schematic()
    })
  end
end
