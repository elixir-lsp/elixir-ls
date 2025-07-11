# codegen: do not edit
defmodule GenLSP.Structures.TypeHierarchySubtypesParams do
  @moduledoc """
  The parameter of a `typeHierarchy/subtypes` request.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * item
  * work_done_token: An optional token that a server can use to report work done progress.
  * partial_result_token: An optional token that a server can use to report partial results (e.g. streaming) to
    the client.
  """

  typedstruct do
    field(:item, GenLSP.Structures.TypeHierarchyItem.t(), enforce: true)
    field(:work_done_token, GenLSP.TypeAlias.ProgressToken.t())
    field(:partial_result_token, GenLSP.TypeAlias.ProgressToken.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"item", :item} => GenLSP.Structures.TypeHierarchyItem.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic(),
      optional({"partialResultToken", :partial_result_token}) =>
        GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
