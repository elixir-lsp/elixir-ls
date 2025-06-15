# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentPrepareTypeHierarchy do
  @moduledoc """
  A request to result a `TypeHierarchyItem` in a document at a given position.
  Can be used as an input to a subtypes or supertypes type hierarchy.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/prepareTypeHierarchy")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.TypeHierarchyPrepareParams.t())
  end

  @type result :: list(GenLSP.Structures.TypeHierarchyItem.t()) | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/prepareTypeHierarchy",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.TypeHierarchyPrepareParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([list(GenLSP.Structures.TypeHierarchyItem.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
