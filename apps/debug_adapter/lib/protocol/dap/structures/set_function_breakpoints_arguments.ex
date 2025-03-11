# codegen: do not edit
defmodule GenDAP.Structures.SetFunctionBreakpointsArguments do
  @moduledoc """
  Arguments for `setFunctionBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * breakpoints: The function names of the breakpoints.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :breakpoints, list(GenDAP.Structures.FunctionBreakpoint.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"breakpoints", :breakpoints} => list(GenDAP.Structures.FunctionBreakpoint.schematic()),
    })
  end
end
