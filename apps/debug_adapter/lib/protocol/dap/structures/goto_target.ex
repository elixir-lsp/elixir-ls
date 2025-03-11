# codegen: do not edit
defmodule GenDAP.Structures.GotoTarget do
  @moduledoc """
  A `GotoTarget` describes a code location that can be used as a target in the `goto` request.
  The possible goto targets can be determined via the `gotoTargets` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * id: Unique identifier for a goto target. This is used in the `goto` request.
  * label: The name of the goto target (shown in the UI).
  * line: The line of the goto target.
  * column: The column of the goto target.
  * end_line: The end line of the range covered by the goto target.
  * end_column: The end column of the range covered by the goto target.
  * instruction_pointer_reference: A memory reference for the instruction pointer value represented by this target.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :id, integer(), enforce: true
    field :label, String.t(), enforce: true
    field :line, integer(), enforce: true
    field :column, integer()
    field :end_line, integer()
    field :end_column, integer()
    field :instruction_pointer_reference, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"id", :id} => int(),
      {"label", :label} => str(),
      {"line", :line} => int(),
      optional({"column", :column}) => int(),
      optional({"endLine", :end_line}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"instructionPointerReference", :instruction_pointer_reference}) => str(),
    })
  end
end
