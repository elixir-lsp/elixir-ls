# codegen: do not edit
defmodule GenLSP.Structures.ApplyWorkspaceEditResult do
  @moduledoc """
  The result returned from the apply workspace edit request.

  @since 3.17 renamed from ApplyWorkspaceEditResponse
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * applied: Indicates whether the edit was applied or not.
  * failure_reason: An optional textual description for why the edit was not applied.
    This may be used by the server for diagnostic logging or to provide
    a suitable error for a request that triggered the edit.
  * failed_change: Depending on the client's failure handling strategy `failedChange` might
    contain the index of the change that failed. This property is only available
    if the client signals a `failureHandlingStrategy` in its client capabilities.
  """
  
  typedstruct do
    field :applied, boolean(), enforce: true
    field :failure_reason, String.t()
    field :failed_change, GenLSP.BaseTypes.uinteger()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"applied", :applied} => bool(),
      optional({"failureReason", :failure_reason}) => str(),
      optional({"failedChange", :failed_change}) => int()
    })
  end
end
