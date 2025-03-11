# codegen: do not edit
defmodule GenDAP.Structures.DisassembledInstruction do
  @moduledoc """
  Represents a single disassembled instruction.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * line: The line within the source location that corresponds to this instruction, if any.
  * address: The address of the instruction. Treated as a hex value if prefixed with `0x`, or as a decimal value otherwise.
  * location: Source location that corresponds to this instruction, if any.
    Should always be set (if available) on the first instruction returned,
    but can be omitted afterwards if this instruction maps to the same source file as the previous instruction.
  * column: The column within the line that corresponds to this instruction, if any.
  * symbol: Name of the symbol that corresponds with the location of this instruction, if any.
  * end_line: The end line of the range that corresponds to this instruction, if any.
  * end_column: The end column of the range that corresponds to this instruction, if any.
  * presentation_hint: A hint for how to present the instruction in the UI.
    
    A value of `invalid` may be used to indicate this instruction is 'filler' and cannot be reached by the program. For example, unreadable memory addresses may be presented is 'invalid.'
  * instruction_bytes: Raw bytes representing the instruction and its operands, in an implementation-defined format.
  * instruction: Text representing the instruction and its operands, in an implementation-defined format.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :line, integer()
    field :address, String.t(), enforce: true
    field :location, GenDAP.Structures.Source.t()
    field :column, integer()
    field :symbol, String.t()
    field :end_line, integer()
    field :end_column, integer()
    field :presentation_hint, String.t()
    field :instruction_bytes, String.t()
    field :instruction, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"line", :line}) => int(),
      {"address", :address} => str(),
      optional({"location", :location}) => GenDAP.Structures.Source.schematic(),
      optional({"column", :column}) => int(),
      optional({"symbol", :symbol}) => str(),
      optional({"endLine", :end_line}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"presentationHint", :presentation_hint}) => oneof(["normal", "invalid"]),
      optional({"instructionBytes", :instruction_bytes}) => str(),
      {"instruction", :instruction} => str(),
    })
  end
end
