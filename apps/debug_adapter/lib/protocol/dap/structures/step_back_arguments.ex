# codegen: do not edit


defmodule GenDAP.Structures.StepBackArguments do
  @moduledoc """
  Arguments for `stepBack` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * granularity: Stepping granularity to step. If no granularity is specified, a granularity of `statement` is assumed.
  * single_thread: If this flag is true, all other suspended threads are not resumed.
  * thread_id: Specifies the thread for which to resume execution for one step backwards (of the given granularity).
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure StepBackArguments"
    field :granularity, GenDAP.Enumerations.SteppingGranularity.t()
    field :single_thread, boolean()
    field :thread_id, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"granularity", :granularity}) => GenDAP.Enumerations.SteppingGranularity.schematic(),
      optional({"singleThread", :single_thread}) => bool(),
      {"threadId", :thread_id} => int(),
    })
  end
end

