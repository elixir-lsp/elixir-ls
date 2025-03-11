# codegen: do not edit
defmodule GenDAP.Structures.ContinueArguments do
  @moduledoc """
  Arguments for `continue` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * thread_id: Specifies the active thread. If the debug adapter supports single thread execution (see `supportsSingleThreadExecutionRequests`) and the argument `singleThread` is true, only the thread with this ID is resumed.
  * single_thread: If this flag is true, execution is resumed only for the thread with given `threadId`.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :thread_id, integer(), enforce: true
    field :single_thread, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"threadId", :thread_id} => int(),
      optional({"singleThread", :single_thread}) => bool(),
    })
  end
end
