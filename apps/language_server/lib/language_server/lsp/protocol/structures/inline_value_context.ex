# codegen: do not edit
defmodule GenLSP.Structures.InlineValueContext do
  @moduledoc """
  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * frame_id: The stack frame (as a DAP Id) where the execution has stopped.
  * stopped_location: The document range where execution has stopped.
    Typically the end position of the range denotes the line where the inline values are shown.
  """
  
  typedstruct do
    field :frame_id, integer(), enforce: true
    field :stopped_location, GenLSP.Structures.Range.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"frameId", :frame_id} => int(),
      {"stoppedLocation", :stopped_location} => GenLSP.Structures.Range.schematic()
    })
  end
end
