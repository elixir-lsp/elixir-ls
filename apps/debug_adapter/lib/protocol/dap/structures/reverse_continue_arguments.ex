# codegen: do not edit
defmodule GenDAP.Structures.ReverseContinueArguments do
  @moduledoc """
  Arguments for `reverseContinue` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * single_thread: If this flag is true, backward execution is resumed only for the thread with given `threadId`.
  * thread_id: Specifies the active thread. If the debug adapter supports single thread execution (see `supportsSingleThreadExecutionRequests`) and the `singleThread` argument is true, only the thread with this ID is resumed.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ReverseContinueArguments"
    field :single_thread, boolean()
    field :thread_id, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"singleThread", :single_thread}) => bool(),
      {"threadId", :thread_id} => int(),
    })
  end
end
