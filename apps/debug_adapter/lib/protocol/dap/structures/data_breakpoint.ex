# codegen: do not edit
defmodule GenDAP.Structures.DataBreakpoint do
  @moduledoc """
  Properties of a data breakpoint passed to the `setDataBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * data_id: An id representing the data. This id is returned from the `dataBreakpointInfo` request.
  * condition: An expression for conditional breakpoints.
  * hit_condition: An expression that controls how many hits of the breakpoint are ignored.
    The debug adapter is expected to interpret the expression as needed.
  * access_type: The access type of the data.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :data_id, String.t(), enforce: true
    field :condition, String.t()
    field :hit_condition, String.t()
    field :access_type, GenDAP.Enumerations.DataBreakpointAccessType.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"dataId", :data_id} => str(),
      optional({"condition", :condition}) => str(),
      optional({"hitCondition", :hit_condition}) => str(),
      optional({"accessType", :access_type}) => GenDAP.Enumerations.DataBreakpointAccessType.schematic(),
    })
  end
end
