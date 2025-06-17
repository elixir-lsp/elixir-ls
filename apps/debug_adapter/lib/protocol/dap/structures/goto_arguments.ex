# codegen: do not edit

defmodule GenDAP.Structures.GotoArguments do
  @moduledoc """
  Arguments for `goto` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * target_id: The location where the debuggee will continue to run.
  * thread_id: Set the goto target for this thread.
  """

  typedstruct do
    @typedoc "A type defining DAP structure GotoArguments"
    field(:target_id, integer(), enforce: true)
    field(:thread_id, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"targetId", :target_id} => int(),
      {"threadId", :thread_id} => int()
    })
  end
end
