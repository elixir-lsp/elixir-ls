# codegen: do not edit

defmodule GenDAP.Structures.ContinueArguments do
  @moduledoc """
  Arguments for `continue` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * single_thread: If this flag is true, execution is resumed only for the thread with given `threadId`.
  * thread_id: Specifies the active thread. If the debug adapter supports single thread execution (see `supportsSingleThreadExecutionRequests`) and the argument `singleThread` is true, only the thread with this ID is resumed.
  """

  typedstruct do
    @typedoc "A type defining DAP structure ContinueArguments"
    field(:single_thread, boolean())
    field(:thread_id, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"singleThread", :single_thread}) => bool(),
      {"threadId", :thread_id} => int()
    })
  end
end
