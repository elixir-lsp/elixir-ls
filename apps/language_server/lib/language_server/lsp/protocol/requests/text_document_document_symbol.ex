# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentDocumentSymbol do
  @moduledoc """
  A request to list all symbols found in a given text document. The request's
  parameter is of type {@link TextDocumentIdentifier} the
  response is of type {@link SymbolInformation SymbolInformation[]} or a Thenable
  that resolves to such.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/documentSymbol")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.DocumentSymbolParams.t())
  end

  @type result ::
          list(GenLSP.Structures.SymbolInformation.t())
          | list(GenLSP.Structures.DocumentSymbol.t())
          | nil

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/documentSymbol",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.DocumentSymbolParams.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      oneof([
        list(GenLSP.Structures.SymbolInformation.schematic()),
        list(GenLSP.Structures.DocumentSymbol.schematic()),
        nil
      ]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
