# codegen: do not edit

defmodule GenDAP.Structures.TerminateThreadsArguments do
  @moduledoc """
  Arguments for `terminateThreads` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * thread_ids: Ids of threads to be terminated.
  """

  typedstruct do
    @typedoc "A type defining DAP structure TerminateThreadsArguments"
    field(:thread_ids, list(integer()))
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"threadIds", :thread_ids}) => list(int())
    })
  end
end
