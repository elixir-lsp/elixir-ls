# codegen: do not edit
defmodule GenLSP.Structures.CallHierarchyIncomingCallsParams do
  @moduledoc """
  The parameter of a `callHierarchy/incomingCalls` request.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * item
  * work_done_token: An optional token that a server can use to report work done progress.
  * partial_result_token: An optional token that a server can use to report partial results (e.g. streaming) to
    the client.
  """
  
  typedstruct do
    field :item, GenLSP.Structures.CallHierarchyItem.t(), enforce: true
    field :work_done_token, GenLSP.TypeAlias.ProgressToken.t()
    field :partial_result_token, GenLSP.TypeAlias.ProgressToken.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"item", :item} => GenLSP.Structures.CallHierarchyItem.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic(),
      optional({"partialResultToken", :partial_result_token}) =>
        GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
