# codegen: do not edit
defmodule GenDAP.Structures.StackFrame do
  @moduledoc """
  A Stackframe contains the source location.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * can_restart: Indicates whether this frame can be restarted with the `restartFrame` request. Clients should only use this if the debug adapter supports the `restart` request and the corresponding capability `supportsRestartFrame` is true. If a debug adapter has this capability, then `canRestart` defaults to `true` if the property is absent.
  * column: Start position of the range covered by the stack frame. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based. If attribute `source` is missing or doesn't exist, `column` is 0 and should be ignored by the client.
  * end_column: End position of the range covered by the stack frame. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_line: The end line of the range covered by the stack frame.
  * id: An identifier for the stack frame. It must be unique across all threads.
    This id can be used to retrieve the scopes of the frame with the `scopes` request or to restart the execution of a stack frame.
  * instruction_pointer_reference: A memory reference for the current instruction pointer in this frame.
  * line: The line within the source of the frame. If the source attribute is missing or doesn't exist, `line` is 0 and should be ignored by the client.
  * module_id: The module associated with this frame, if any.
  * name: The name of the stack frame, typically a method name.
  * presentation_hint: A hint for how to present this frame in the UI.
    A value of `label` can be used to indicate that the frame is an artificial frame that is used as a visual label or separator. A value of `subtle` can be used to change the appearance of a frame in a 'subtle' way.
  * source: The source of the frame.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure StackFrame"
    field :can_restart, boolean()
    field :column, integer(), enforce: true
    field :end_column, integer()
    field :end_line, integer()
    field :id, integer(), enforce: true
    field :instruction_pointer_reference, String.t()
    field :line, integer(), enforce: true
    field :module_id, integer() | String.t()
    field :name, String.t(), enforce: true
    field :presentation_hint, String.t()
    field :source, GenDAP.Structures.Source.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"canRestart", :can_restart}) => bool(),
      {"column", :column} => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      {"id", :id} => int(),
      optional({"instructionPointerReference", :instruction_pointer_reference}) => str(),
      {"line", :line} => int(),
      optional({"moduleId", :module_id}) => oneof([int(), str()]),
      {"name", :name} => str(),
      optional({"presentationHint", :presentation_hint}) => oneof(["normal", "label", "subtle"]),
      optional({"source", :source}) => GenDAP.Structures.Source.schematic(),
    })
  end
end
