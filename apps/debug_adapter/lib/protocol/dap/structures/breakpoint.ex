# codegen: do not edit

defmodule GenDAP.Structures.Breakpoint do
  @moduledoc """
  Information about a breakpoint created in `setBreakpoints`, `setFunctionBreakpoints`, `setInstructionBreakpoints`, or `setDataBreakpoints` requests.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * column: Start position of the source range covered by the breakpoint. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_column: End position of the source range covered by the breakpoint. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
    If no end line is given, then the end column is assumed to be in the start line.
  * end_line: The end line of the actual range covered by the breakpoint.
  * id: The identifier for the breakpoint. It is needed if breakpoint events are used to update or remove breakpoints.
  * instruction_reference: A memory reference to where the breakpoint is set.
  * line: The start line of the actual range covered by the breakpoint.
  * message: A message about the state of the breakpoint.
    This is shown to the user and can be used to explain why a breakpoint could not be verified.
  * offset: The offset from the instruction reference.
    This can be negative.
  * reason: A machine-readable explanation of why a breakpoint may not be verified. If a breakpoint is verified or a specific reason is not known, the adapter should omit this property. Possible values include:
    
    - `pending`: Indicates a breakpoint might be verified in the future, but the adapter cannot verify it in the current state.
     - `failed`: Indicates a breakpoint was not able to be verified, and the adapter does not believe it can be verified without intervention.
  * source: The source where the breakpoint is located.
  * verified: If true, the breakpoint could be set (but not necessarily at the desired location).
  """

  typedstruct do
    @typedoc "A type defining DAP structure Breakpoint"
    field(:column, integer())
    field(:end_column, integer())
    field(:end_line, integer())
    field(:id, integer())
    field(:instruction_reference, String.t())
    field(:line, integer())
    field(:message, String.t())
    field(:offset, integer())
    field(:reason, String.t())
    field(:source, GenDAP.Structures.Source.t())
    field(:verified, boolean(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      optional({"id", :id}) => int(),
      optional({"instructionReference", :instruction_reference}) => str(),
      optional({"line", :line}) => int(),
      optional({"message", :message}) => str(),
      optional({"offset", :offset}) => int(),
      optional({"reason", :reason}) => oneof(["pending", "failed"]),
      optional({"source", :source}) => GenDAP.Structures.Source.schematic(),
      {"verified", :verified} => bool()
    })
  end
end
