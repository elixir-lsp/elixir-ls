# codegen: do not edit

defmodule GenDAP.Structures.SetFunctionBreakpointsArguments do
  @moduledoc """
  Arguments for `setFunctionBreakpoints` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * breakpoints: The function names of the breakpoints.
  """

  typedstruct do
    @typedoc "A type defining DAP structure SetFunctionBreakpointsArguments"
    field(:breakpoints, list(GenDAP.Structures.FunctionBreakpoint.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"breakpoints", :breakpoints} => list(GenDAP.Structures.FunctionBreakpoint.schematic())
    })
  end
end
