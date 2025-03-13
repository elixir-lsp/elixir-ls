# codegen: do not edit
defmodule GenDAP.Structures.DisassembleArguments do
  @moduledoc """
  Arguments for `disassemble` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * instruction_count: Number of instructions to disassemble starting at the specified location and offset.
    An adapter must return exactly this number of instructions - any unavailable instructions should be replaced with an implementation-defined 'invalid instruction' value.
  * instruction_offset: Offset (in instructions) to be applied after the byte offset (if any) before disassembling. Can be negative.
  * memory_reference: Memory reference to the base location containing the instructions to disassemble.
  * offset: Offset (in bytes) to be applied to the reference location before disassembling. Can be negative.
  * resolve_symbols: If true, the adapter should attempt to resolve memory addresses and other values to symbolic names.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure DisassembleArguments"
    field :instruction_count, integer(), enforce: true
    field :instruction_offset, integer()
    field :memory_reference, String.t(), enforce: true
    field :offset, integer()
    field :resolve_symbols, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"instructionCount", :instruction_count} => int(),
      optional({"instructionOffset", :instruction_offset}) => int(),
      {"memoryReference", :memory_reference} => str(),
      optional({"offset", :offset}) => int(),
      optional({"resolveSymbols", :resolve_symbols}) => bool(),
    })
  end
end
