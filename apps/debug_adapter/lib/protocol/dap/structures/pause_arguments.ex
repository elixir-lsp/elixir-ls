# codegen: do not edit

defmodule GenDAP.Structures.PauseArguments do
  @moduledoc """
  Arguments for `pause` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * thread_id: Pause execution for this thread.
  """

  typedstruct do
    @typedoc "A type defining DAP structure PauseArguments"
    field(:thread_id, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"threadId", :thread_id} => int()
    })
  end
end
