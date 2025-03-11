# codegen: do not edit
defmodule GenDAP.Structures.GotoArguments do
  @moduledoc """
  Arguments for `goto` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * thread_id: Set the goto target for this thread.
  * target_id: The location where the debuggee will continue to run.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :thread_id, integer(), enforce: true
    field :target_id, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"threadId", :thread_id} => int(),
      {"targetId", :target_id} => int(),
    })
  end
end
