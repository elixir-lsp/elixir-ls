# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokensEdit do
  @moduledoc """
  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * start: The start offset of the edit.
  * delete_count: The count of elements to remove.
  * data: The elements to insert.
  """
  
  typedstruct do
    field :start, GenLSP.BaseTypes.uinteger(), enforce: true
    field :delete_count, GenLSP.BaseTypes.uinteger(), enforce: true
    field :data, list(GenLSP.BaseTypes.uinteger())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"start", :start} => int(),
      {"deleteCount", :delete_count} => int(),
      optional({"data", :data}) => list(int())
    })
  end
end
