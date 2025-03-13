# codegen: do not edit
defmodule GenDAP.Structures.DisassembledInstruction do
  @moduledoc """
  Represents a single disassembled instruction.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * address: The address of the instruction. Treated as a hex value if prefixed with `0x`, or as a decimal value otherwise.
  * column: The column within the line that corresponds to this instruction, if any.
  * end_column: The end column of the range that corresponds to this instruction, if any.
  * end_line: The end line of the range that corresponds to this instruction, if any.
  * instruction: Text representing the instruction and its operands, in an implementation-defined format.
  * instruction_bytes: Raw bytes representing the instruction and its operands, in an implementation-defined format.
  * line: The line within the source location that corresponds to this instruction, if any.
  * location: Source location that corresponds to this instruction, if any.
    Should always be set (if available) on the first instruction returned,
    but can be omitted afterwards if this instruction maps to the same source file as the previous instruction.
  * presentation_hint: A hint for how to present the instruction in the UI.
    
    A value of `invalid` may be used to indicate this instruction is 'filler' and cannot be reached by the program. For example, unreadable memory addresses may be presented is 'invalid.'
  * symbol: Name of the symbol that corresponds with the location of this instruction, if any.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure DisassembledInstruction"
    field :address, String.t(), enforce: true
    field :column, integer()
    field :end_column, integer()
    field :end_line, integer()
    field :instruction, String.t(), enforce: true
    field :instruction_bytes, String.t()
    field :line, integer()
    field :location, GenDAP.Structures.Source.t()
    field :presentation_hint, String.t()
    field :symbol, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"address", :address} => str(),
      optional({"column", :column}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      {"instruction", :instruction} => str(),
      optional({"instructionBytes", :instruction_bytes}) => str(),
      optional({"line", :line}) => int(),
      optional({"location", :location}) => GenDAP.Structures.Source.schematic(),
      optional({"presentationHint", :presentation_hint}) => oneof(["normal", "invalid"]),
      optional({"symbol", :symbol}) => str(),
    })
  end
end
