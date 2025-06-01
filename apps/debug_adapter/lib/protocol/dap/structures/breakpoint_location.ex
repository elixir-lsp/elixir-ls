# codegen: do not edit

defmodule GenDAP.Structures.BreakpointLocation do
  @moduledoc """
  Properties of a breakpoint location returned from the `breakpointLocations` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * column: The start position of a breakpoint location. Position is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_column: The end position of a breakpoint location (if the location covers a range). Position is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_line: The end line of breakpoint location if the location covers a range.
  * line: Start line of breakpoint location.
  """

  typedstruct do
    @typedoc "A type defining DAP structure BreakpointLocation"
    field(:column, integer())
    field(:end_column, integer())
    field(:end_line, integer())
    field(:line, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      {"line", :line} => int()
    })
  end
end
