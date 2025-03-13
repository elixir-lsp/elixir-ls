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
  
  * column: The column of the goto target.
  * end_column: The end column of the range covered by the goto target.
  * end_line: The end line of the range covered by the goto target.
  * id: Unique identifier for a goto target. This is used in the `goto` request.
  * instruction_pointer_reference: A memory reference for the instruction pointer value represented by this target.
  * label: The name of the goto target (shown in the UI).
  * line: The line of the goto target.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure GotoTarget"
    field :column, integer()
    field :end_column, integer()
    field :end_line, integer()
    field :id, integer(), enforce: true
    field :instruction_pointer_reference, String.t()
    field :label, String.t(), enforce: true
    field :line, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      {"id", :id} => int(),
      optional({"instructionPointerReference", :instruction_pointer_reference}) => str(),
      {"label", :label} => str(),
      {"line", :line} => int(),
    })
  end
end
