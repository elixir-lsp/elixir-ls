# codegen: do not edit
defmodule GenDAP.Structures.StepBackArguments do
  @moduledoc """
  Arguments for `stepBack` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * thread_id: Specifies the thread for which to resume execution for one step backwards (of the given granularity).
  * single_thread: If this flag is true, all other suspended threads are not resumed.
  * granularity: Stepping granularity to step. If no granularity is specified, a granularity of `statement` is assumed.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :thread_id, integer(), enforce: true
    field :single_thread, boolean()
    field :granularity, GenDAP.Enumerations.SteppingGranularity.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"threadId", :thread_id} => int(),
      optional({"singleThread", :single_thread}) => bool(),
      optional({"granularity", :granularity}) => GenDAP.Enumerations.SteppingGranularity.schematic(),
    })
  end
end
