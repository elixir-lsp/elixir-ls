# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentFoldingRange do
  @moduledoc """
  A request to provide folding ranges in a document. The request's
  parameter is of type {@link FoldingRangeParams}, the
  response is of type {@link FoldingRangeList} or a Thenable
  that resolves to such.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "textDocument/foldingRange"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.FoldingRangeParams.t()
  end

  @type result :: list(GenLSP.Structures.FoldingRange.t()) | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/foldingRange",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.FoldingRangeParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([list(GenLSP.Structures.FoldingRange.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
