# codegen: do not edit

defmodule GenDAP.Structures.ExceptionPathSegment do
  @moduledoc """
  An `ExceptionPathSegment` represents a segment in a path that is used to match leafs or nodes in a tree of exceptions.
  If a segment consists of more than one name, it matches the names provided if `negate` is false or missing, or it matches anything except the names provided if `negate` is true.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * names: Depending on the value of `negate` the names that should match or not match.
  * negate: If false or missing this segment matches the names provided, otherwise it matches anything except the names provided.
  """

  typedstruct do
    @typedoc "A type defining DAP structure ExceptionPathSegment"
    field(:names, list(String.t()), enforce: true)
    field(:negate, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"names", :names} => list(str()),
      optional({"negate", :negate}) => bool()
    })
  end
end
