# codegen: do not edit
defmodule GenDAP.Structures.ReverseContinueArguments do
  @moduledoc """
  Arguments for `reverseContinue` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * thread_id: Specifies the active thread. If the debug adapter supports single thread execution (see `supportsSingleThreadExecutionRequests`) and the `singleThread` argument is true, only the thread with this ID is resumed.
  * single_thread: If this flag is true, backward execution is resumed only for the thread with given `threadId`.
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
