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
  * offset: Offset (in bytes) to be applied to the reference location before reading data. Can be negative.
  * memory_reference: Memory reference to the base location from which data should be read.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :count, integer(), enforce: true
    field :offset, integer()
    field :memory_reference, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"count", :count} => int(),
      optional({"offset", :offset}) => int(),
      {"memoryReference", :memory_reference} => str(),
    })
  end
end
