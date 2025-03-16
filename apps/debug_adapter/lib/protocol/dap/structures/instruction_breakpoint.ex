# codegen: do not edit


defmodule GenDAP.Structures.InstructionBreakpoint do
  @moduledoc """
  Properties of a breakpoint passed to the `setInstructionBreakpoints` request
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * condition: An expression for conditional breakpoints.
    It is only honored by a debug adapter if the corresponding capability `supportsConditionalBreakpoints` is true.
  * hit_condition: An expression that controls how many hits of the breakpoint are ignored.
    The debug adapter is expected to interpret the expression as needed.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsHitConditionalBreakpoints` is true.
  * instruction_reference: The instruction reference of the breakpoint.
    This should be a memory or instruction pointer reference from an `EvaluateResponse`, `Variable`, `StackFrame`, `GotoTarget`, or `Breakpoint`.
  * mode: The mode of this breakpoint. If defined, this must be one of the `breakpointModes` the debug adapter advertised in its `Capabilities`.
  * offset: The offset from the instruction reference in bytes.
    This can be negative.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure InstructionBreakpoint"
    field :condition, String.t()
    field :hit_condition, String.t()
    field :instruction_reference, String.t(), enforce: true
    field :mode, String.t()
    field :offset, integer()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"condition", :condition}) => str(),
      optional({"hitCondition", :hit_condition}) => str(),
      {"instructionReference", :instruction_reference} => str(),
      optional({"mode", :mode}) => str(),
      optional({"offset", :offset}) => int(),
    })
  end
end

