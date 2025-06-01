# codegen: do not edit

defmodule GenDAP.Structures.RestartFrameArguments do
  @moduledoc """
  Arguments for `restartFrame` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * frame_id: Restart the stack frame identified by `frameId`. The `frameId` must have been obtained in the current suspended state. See 'Lifetime of Object References' in the Overview section for details.
  """

  typedstruct do
    @typedoc "A type defining DAP structure RestartFrameArguments"
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
