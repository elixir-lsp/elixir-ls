# codegen: do not edit

defmodule GenDAP.Structures.SetBreakpointsArguments do
  @moduledoc """
  Arguments for `setBreakpoints` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * breakpoints: The code locations of the breakpoints.
  * lines: Deprecated: The code locations of the breakpoints.
  * source: The source location of the breakpoints; either `source.path` or `source.sourceReference` must be specified.
  * source_modified: A value of true indicates that the underlying source has been modified which results in new breakpoint locations.
  """

  typedstruct do
    @typedoc "A type defining DAP structure SetBreakpointsArguments"
    field(:breakpoints, list(GenDAP.Structures.SourceBreakpoint.t()))
    field(:lines, list(integer()))
    field(:source, GenDAP.Structures.Source.t(), enforce: true)
    field(:source_modified, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"breakpoints", :breakpoints}) =>
        list(GenDAP.Structures.SourceBreakpoint.schematic()),
      optional({"lines", :lines}) => list(int()),
      {"source", :source} => GenDAP.Structures.Source.schematic(),
      optional({"sourceModified", :source_modified}) => bool()
    })
  end
end
