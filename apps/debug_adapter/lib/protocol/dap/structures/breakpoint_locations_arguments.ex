# codegen: do not edit

defmodule GenDAP.Structures.BreakpointLocationsArguments do
  @moduledoc """
  Arguments for `breakpointLocations` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * column: Start position within `line` to search possible breakpoint locations in. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based. If no column is given, the first position in the start line is assumed.
  * end_column: End position within `endLine` to search possible breakpoint locations in. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based. If no end column is given, the last position in the end line is assumed.
  * end_line: End line of range to search possible breakpoint locations in. If no end line is given, then the end line is assumed to be the start line.
  * line: Start line of range to search possible breakpoint locations in. If only the line is specified, the request returns all possible locations in that line.
  * source: The source location of the breakpoints; either `source.path` or `source.sourceReference` must be specified.
  """

  typedstruct do
    @typedoc "A type defining DAP structure BreakpointLocationsArguments"
    field(:column, integer())
    field(:end_column, integer())
    field(:end_line, integer())
    field(:line, integer(), enforce: true)
    field(:source, GenDAP.Structures.Source.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      {"line", :line} => int(),
      {"source", :source} => GenDAP.Structures.Source.schematic()
    })
  end
end
