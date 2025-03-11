# codegen: do not edit
defmodule GenDAP.Structures.BreakpointLocation do
  @moduledoc """
  Properties of a breakpoint location returned from the `breakpointLocations` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * line: Start line of breakpoint location.
  * column: The start position of a breakpoint location. Position is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_line: The end line of breakpoint location if the location covers a range.
  * end_column: The end position of a breakpoint location (if the location covers a range). Position is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :line, integer(), enforce: true
    field :column, integer()
    field :end_line, integer()
    field :end_column, integer()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"line", :line} => int(),
      optional({"column", :column}) => int(),
      optional({"endLine", :end_line}) => int(),
      optional({"endColumn", :end_column}) => int(),
    })
  end
end
