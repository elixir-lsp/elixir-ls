# codegen: do not edit

defmodule GenDAP.Structures.FunctionBreakpoint do
  @moduledoc """
  Properties of a breakpoint passed to the `setFunctionBreakpoints` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * condition: An expression for conditional breakpoints.
    It is only honored by a debug adapter if the corresponding capability `supportsConditionalBreakpoints` is true.
  * hit_condition: An expression that controls how many hits of the breakpoint are ignored.
    The debug adapter is expected to interpret the expression as needed.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsHitConditionalBreakpoints` is true.
  * name: The name of the function.
  """

  typedstruct do
    @typedoc "A type defining DAP structure FunctionBreakpoint"
    field(:condition, String.t())
    field(:hit_condition, String.t())
    field(:name, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"condition", :condition}) => str(),
      optional({"hitCondition", :hit_condition}) => str(),
      {"name", :name} => str()
    })
  end
end
