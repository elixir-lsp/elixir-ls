# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentWillSaveWaitUntil do
  @moduledoc """
  A document will save request is sent from the client to the server before
  the document is actually saved. The request can return an array of TextEdits
  which will be applied to the text document before it is saved. Please note that
  clients might drop results if computing the text edits took too long or if a
  server constantly fails on this request. This is done to keep the save fast and
  reliable.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "textDocument/willSaveWaitUntil"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.WillSaveTextDocumentParams.t()
  end

  @type result :: list(GenLSP.Structures.TextEdit.t()) | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/willSaveWaitUntil",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.WillSaveTextDocumentParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([list(GenLSP.Structures.TextEdit.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
