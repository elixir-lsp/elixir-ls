# codegen: do not edit
defmodule GenDAP.Structures.SetBreakpointsArguments do
  @moduledoc """
  Arguments for `setBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * source: The source location of the breakpoints; either `source.path` or `source.sourceReference` must be specified.
  * lines: Deprecated: The code locations of the breakpoints.
  * breakpoints: The code locations of the breakpoints.
  * source_modified: A value of true indicates that the underlying source has been modified which results in new breakpoint locations.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :source, GenDAP.Structures.Source.t(), enforce: true
    field :lines, list(integer())
    field :breakpoints, list(GenDAP.Structures.SourceBreakpoint.t())
    field :source_modified, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"source", :source} => GenDAP.Structures.Source.schematic(),
      optional({"lines", :lines}) => list(int()),
      optional({"breakpoints", :breakpoints}) => list(GenDAP.Structures.SourceBreakpoint.schematic()),
      optional({"sourceModified", :source_modified}) => bool(),
    })
  end
end
