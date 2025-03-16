# codegen: do not edit

defmodule GenDAP.Structures.StepInArguments do
  @moduledoc """
  Arguments for `stepIn` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * granularity: Stepping granularity. If no granularity is specified, a granularity of `statement` is assumed.
  * single_thread: If this flag is true, all other suspended threads are not resumed.
  * target_id: Id of the target to step into.
  * thread_id: Specifies the thread for which to resume execution for one step-into (of the given granularity).
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure StepInArguments"
    field(:granularity, GenDAP.Enumerations.SteppingGranularity.t())
    field(:single_thread, boolean())
    field(:target_id, integer())
    field(:thread_id, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"granularity", :granularity}) =>
        GenDAP.Enumerations.SteppingGranularity.schematic(),
      optional({"singleThread", :single_thread}) => bool(),
      optional({"targetId", :target_id}) => int(),
      {"threadId", :thread_id} => int()
    })
  end
end
