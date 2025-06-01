# codegen: do not edit

defmodule GenDAP.Structures.SetDataBreakpointsArguments do
  @moduledoc """
  Arguments for `setDataBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * breakpoints: The contents of this array replaces all existing data breakpoints. An empty array clears all data breakpoints.
  """

  typedstruct do
    @typedoc "A type defining DAP structure SetDataBreakpointsArguments"
    field(:breakpoints, list(GenDAP.Structures.DataBreakpoint.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"breakpoints", :breakpoints} => list(GenDAP.Structures.DataBreakpoint.schematic())
    })
  end
end
