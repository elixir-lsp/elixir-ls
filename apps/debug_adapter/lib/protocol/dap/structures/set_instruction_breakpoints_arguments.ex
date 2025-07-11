# codegen: do not edit

defmodule GenDAP.Structures.SetInstructionBreakpointsArguments do
  @moduledoc """
  Arguments for `setInstructionBreakpoints` request
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * breakpoints: The instruction references of the breakpoints
  """

  typedstruct do
    @typedoc "A type defining DAP structure SetInstructionBreakpointsArguments"
    field(:breakpoints, list(GenDAP.Structures.InstructionBreakpoint.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"breakpoints", :breakpoints} => list(GenDAP.Structures.InstructionBreakpoint.schematic())
    })
  end
end
