# codegen: do not edit
defmodule GenDAP.Structures.ExceptionInfoArguments do
  @moduledoc """
  Arguments for `exceptionInfo` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * thread_id: Thread for which exception information should be retrieved.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :thread_id, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"threadId", :thread_id} => int(),
    })
  end
end
