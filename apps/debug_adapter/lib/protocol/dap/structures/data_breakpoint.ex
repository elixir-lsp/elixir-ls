# codegen: do not edit

defmodule GenDAP.Structures.DataBreakpoint do
  @moduledoc """
  Properties of a data breakpoint passed to the `setDataBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * access_type: The access type of the data.
  * condition: An expression for conditional breakpoints.
  * data_id: An id representing the data. This id is returned from the `dataBreakpointInfo` request.
  * hit_condition: An expression that controls how many hits of the breakpoint are ignored.
    The debug adapter is expected to interpret the expression as needed.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure DataBreakpoint"
    field(:access_type, GenDAP.Enumerations.DataBreakpointAccessType.t())
    field(:condition, String.t())
    field(:data_id, String.t(), enforce: true)
    field(:hit_condition, String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"accessType", :access_type}) =>
        GenDAP.Enumerations.DataBreakpointAccessType.schematic(),
      optional({"condition", :condition}) => str(),
      {"dataId", :data_id} => str(),
      optional({"hitCondition", :hit_condition}) => str()
    })
  end
end
