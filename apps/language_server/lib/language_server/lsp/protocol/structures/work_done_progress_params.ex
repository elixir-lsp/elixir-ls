# codegen: do not edit
defmodule GenLSP.Structures.WorkDoneProgressParams do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * work_done_token: An optional token that a server can use to report work done progress.
  """

  typedstruct do
    field(:work_done_token, GenLSP.TypeAlias.ProgressToken.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
