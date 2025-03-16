# codegen: do not edit

defmodule GenDAP.Structures.StepInTargetsArguments do
  @moduledoc """
  Arguments for `stepInTargets` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * frame_id: The stack frame for which to retrieve the possible step-in targets.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure StepInTargetsArguments"
    field(:frame_id, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"frameId", :frame_id} => int()
    })
  end
end
