# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentDocumentHighlight do
  @moduledoc """
  Request to resolve a {@link DocumentHighlight} for a given
  text document position. The request's parameter is of type [TextDocumentPosition]
  (#TextDocumentPosition) the request response is of type [DocumentHighlight[]]
  (#DocumentHighlight) or a Thenable that resolves to such.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/documentHighlight")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.DocumentHighlightParams.t())
  end

  @type result :: list(GenLSP.Structures.DocumentHighlight.t()) | nil

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/documentHighlight",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.DocumentHighlightParams.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      oneof([list(GenLSP.Structures.DocumentHighlight.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
