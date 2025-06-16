# codegen: do not edit

defmodule GenDAP.Structures.StepInTarget do
  @moduledoc """
  A `StepInTarget` can be used in the `stepIn` request and determines into which single target the `stepIn` request should step.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * column: Start position of the range covered by the step in target. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_column: End position of the range covered by the step in target. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_line: The end line of the range covered by the step-in target.
  * id: Unique identifier for a step-in target.
  * label: The name of the step-in target (shown in the UI).
  * line: The line of the step-in target.
  """

  typedstruct do
    @typedoc "A type defining DAP structure StepInTarget"
    field(:column, integer())
    field(:end_column, integer())
    field(:end_line, integer())
    field(:id, integer(), enforce: true)
    field(:label, String.t(), enforce: true)
    field(:line, integer())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      {"id", :id} => int(),
      {"label", :label} => str(),
      optional({"line", :line}) => int()
    })
  end
end
