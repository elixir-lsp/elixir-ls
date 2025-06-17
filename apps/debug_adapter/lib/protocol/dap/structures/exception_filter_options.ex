# codegen: do not edit

defmodule GenDAP.Structures.ExceptionFilterOptions do
  @moduledoc """
  An `ExceptionFilterOptions` is used to specify an exception filter together with a condition for the `setExceptionBreakpoints` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * condition: An expression for conditional exceptions.
    The exception breaks into the debugger if the result of the condition is true.
  * filter_id: ID of an exception filter returned by the `exceptionBreakpointFilters` capability.
  * mode: The mode of this exception breakpoint. If defined, this must be one of the `breakpointModes` the debug adapter advertised in its `Capabilities`.
  """

  typedstruct do
    @typedoc "A type defining DAP structure ExceptionFilterOptions"
    field(:condition, String.t())
    field(:filter_id, String.t(), enforce: true)
    field(:mode, String.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"condition", :condition}) => str(),
      {"filterId", :filter_id} => str(),
      optional({"mode", :mode}) => str()
    })
  end
end
