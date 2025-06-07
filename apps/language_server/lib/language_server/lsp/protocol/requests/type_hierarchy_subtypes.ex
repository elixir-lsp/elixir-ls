# codegen: do not edit
defmodule GenLSP.Requests.TypeHierarchySubtypes do
  @moduledoc """
  A request to resolve the subtypes for a given `TypeHierarchyItem`.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "typeHierarchy/subtypes"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.TypeHierarchySubtypesParams.t()
  end

  @type result :: list(GenLSP.Structures.TypeHierarchyItem.t()) | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "typeHierarchy/subtypes",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.TypeHierarchySubtypesParams.schematic()
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
