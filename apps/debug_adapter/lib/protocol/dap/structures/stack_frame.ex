# codegen: do not edit
defmodule GenDAP.Structures.StackFrame do
  @moduledoc """
  A Stackframe contains the source location.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * id: An identifier for the stack frame. It must be unique across all threads.
    This id can be used to retrieve the scopes of the frame with the `scopes` request or to restart the execution of a stack frame.
  * line: The line within the source of the frame. If the source attribute is missing or doesn't exist, `line` is 0 and should be ignored by the client.
  * name: The name of the stack frame, typically a method name.
  * column: Start position of the range covered by the stack frame. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based. If attribute `source` is missing or doesn't exist, `column` is 0 and should be ignored by the client.
  * source: The source of the frame.
  * end_line: The end line of the range covered by the stack frame.
  * end_column: End position of the range covered by the stack frame. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * presentation_hint: A hint for how to present this frame in the UI.
    A value of `label` can be used to indicate that the frame is an artificial frame that is used as a visual label or separator. A value of `subtle` can be used to change the appearance of a frame in a 'subtle' way.
  * can_restart: Indicates whether this frame can be restarted with the `restartFrame` request. Clients should only use this if the debug adapter supports the `restart` request and the corresponding capability `supportsRestartFrame` is true. If a debug adapter has this capability, then `canRestart` defaults to `true` if the property is absent.
  * instruction_pointer_reference: A memory reference for the current instruction pointer in this frame.
  * module_id: The module associated with this frame, if any.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :id, integer(), enforce: true
    field :line, integer(), enforce: true
    field :name, String.t(), enforce: true
    field :column, integer(), enforce: true
    field :source, GenDAP.Structures.Source.t()
    field :end_line, integer()
    field :end_column, integer()
    field :presentation_hint, String.t()
    field :can_restart, boolean()
    field :instruction_pointer_reference, String.t()
    field :module_id, integer() | String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"id", :id} => int(),
      {"line", :line} => int(),
      {"name", :name} => str(),
      {"column", :column} => int(),
      optional({"source", :source}) => GenDAP.Structures.Source.schematic(),
      optional({"endLine", :end_line}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"presentationHint", :presentation_hint}) => oneof(["normal", "label", "subtle"]),
      optional({"canRestart", :can_restart}) => bool(),
      optional({"instructionPointerReference", :instruction_pointer_reference}) => str(),
      optional({"moduleId", :module_id}) => oneof([int(), str()]),
    })
  end
end
