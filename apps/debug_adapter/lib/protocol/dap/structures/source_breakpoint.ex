# codegen: do not edit
defmodule GenDAP.Structures.SourceBreakpoint do
  @moduledoc """
  Properties of a breakpoint or logpoint passed to the `setBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * line: The source line of the breakpoint or logpoint.
  * mode: The mode of this breakpoint. If defined, this must be one of the `breakpointModes` the debug adapter advertised in its `Capabilities`.
  * column: Start position within source line of the breakpoint or logpoint. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * condition: The expression for conditional breakpoints.
    It is only honored by a debug adapter if the corresponding capability `supportsConditionalBreakpoints` is true.
  * hit_condition: The expression that controls how many hits of the breakpoint are ignored.
    The debug adapter is expected to interpret the expression as needed.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsHitConditionalBreakpoints` is true.
    If both this property and `condition` are specified, `hitCondition` should be evaluated only if the `condition` is met, and the debug adapter should stop only if both conditions are met.
  * log_message: If this attribute exists and is non-empty, the debug adapter must not 'break' (stop)
    but log the message instead. Expressions within `{}` are interpolated.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsLogPoints` is true.
    If either `hitCondition` or `condition` is specified, then the message should only be logged if those conditions are met.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :line, integer(), enforce: true
    field :mode, String.t()
    field :column, integer()
    field :condition, String.t()
    field :hit_condition, String.t()
    field :log_message, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"line", :line} => int(),
      optional({"mode", :mode}) => str(),
      optional({"column", :column}) => int(),
      optional({"condition", :condition}) => str(),
      optional({"hitCondition", :hit_condition}) => str(),
      optional({"logMessage", :log_message}) => str(),
    })
  end
end
