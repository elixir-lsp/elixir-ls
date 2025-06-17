# codegen: do not edit
defmodule GenLSP.Structures.CallHierarchyOptions do
  @moduledoc """
  Call hierarchy options used during static registration.

  @since 3.16.0
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
