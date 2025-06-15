# codegen: do not edit
defmodule GenLSP.Structures.Range do
  @moduledoc """
  A range in a text document expressed as (zero-based) start and end positions.

  If you want to specify a range that contains a line including the line ending
  character(s) then use an end position denoting the start of the next line.
  For example:
  ```ts
  {
      start: { line: 5, character: 23 }
      end : { line 6, character : 0 }
  }
  ```
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * start: The range's start position.
  * end: The range's end position.
  """

  typedstruct do
    field(:start, GenLSP.Structures.Position.t(), enforce: true)
    field(:end, GenLSP.Structures.Position.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"start", :start} => GenLSP.Structures.Position.schematic(),
      {"end", :end} => GenLSP.Structures.Position.schematic()
    })
  end
end
