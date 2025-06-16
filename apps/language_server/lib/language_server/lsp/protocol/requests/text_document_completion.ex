# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentCompletion do
  @moduledoc """
  Request to request completion at a given text document position. The request's
  parameter is of type {@link TextDocumentPosition} the response
  is of type {@link CompletionItem CompletionItem[]} or {@link CompletionList}
  or a Thenable that resolves to such.

  The request can delay the computation of the {@link CompletionItem.detail `detail`}
  and {@link CompletionItem.documentation `documentation`} properties to the `completionItem/resolve`
  request. However, properties that are needed for the initial sorting and filtering, like `sortText`,
  `filterText`, `insertText`, and `textEdit`, must not be changed during resolve.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/completion")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.CompletionParams.t())
  end

  @type result ::
          list(GenLSP.Structures.CompletionItem.t()) | GenLSP.Structures.CompletionList.t() | nil

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/completion",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.CompletionParams.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      oneof([
        list(GenLSP.Structures.CompletionItem.schematic()),
        GenLSP.Structures.CompletionList.schematic(),
        nil
      ]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
