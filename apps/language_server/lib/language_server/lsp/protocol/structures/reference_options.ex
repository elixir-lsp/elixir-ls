# codegen: do not edit
defmodule GenLSP.Structures.ReferenceOptions do
  @moduledoc """
  Reference options.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * work_done_progress
  """

  typedstruct do
    field(:work_done_progress, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"workDoneProgress", :work_done_progress}) => bool()
    })
  end
end
