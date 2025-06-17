# codegen: do not edit

defmodule GenDAP.Structures.StepOutArguments do
  @moduledoc """
  Arguments for `stepOut` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * granularity: Stepping granularity. If no granularity is specified, a granularity of `statement` is assumed.
  * single_thread: If this flag is true, all other suspended threads are not resumed.
  * thread_id: Specifies the thread for which to resume execution for one step-out (of the given granularity).
  """

  typedstruct do
    @typedoc "A type defining DAP structure StepOutArguments"
    field(:granularity, GenDAP.Enumerations.SteppingGranularity.t())
    field(:single_thread, boolean())
    field(:thread_id, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"granularity", :granularity}) =>
        GenDAP.Enumerations.SteppingGranularity.schematic(),
      optional({"singleThread", :single_thread}) => bool(),
      {"threadId", :thread_id} => int()
    })
  end
end
