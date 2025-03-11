# codegen: do not edit
defmodule GenDAP.Structures.WriteMemoryArguments do
  @moduledoc """
  Arguments for `writeMemory` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * data: Bytes to write, encoded using base64.
  * offset: Offset (in bytes) to be applied to the reference location before writing data. Can be negative.
  * memory_reference: Memory reference to the base location to which data should be written.
  * allow_partial: Property to control partial writes. If true, the debug adapter should attempt to write memory even if the entire memory region is not writable. In such a case the debug adapter should stop after hitting the first byte of memory that cannot be written and return the number of bytes written in the response via the `offset` and `bytesWritten` properties.
    If false or missing, a debug adapter should attempt to verify the region is writable before writing, and fail the response if it is not.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :data, String.t(), enforce: true
    field :offset, integer()
    field :memory_reference, String.t(), enforce: true
    field :allow_partial, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"data", :data} => str(),
      optional({"offset", :offset}) => int(),
      {"memoryReference", :memory_reference} => str(),
      optional({"allowPartial", :allow_partial}) => bool(),
    })
  end
end
