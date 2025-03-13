# codegen: do not edit
defmodule GenDAP.Structures.ReadMemoryArguments do
  @moduledoc """
  Arguments for `readMemory` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * count: Number of bytes to read at the specified location and offset.
  * memory_reference: Memory reference to the base location from which data should be read.
  * offset: Offset (in bytes) to be applied to the reference location before reading data. Can be negative.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ReadMemoryArguments"
    field :count, integer(), enforce: true
    field :memory_reference, String.t(), enforce: true
    field :offset, integer()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"count", :count} => int(),
      {"memoryReference", :memory_reference} => str(),
      optional({"offset", :offset}) => int(),
    })
  end
end
