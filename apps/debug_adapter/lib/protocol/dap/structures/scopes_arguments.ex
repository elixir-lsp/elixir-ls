# codegen: do not edit

defmodule GenDAP.Structures.ScopesArguments do
  @moduledoc """
  Arguments for `scopes` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * frame_id: Retrieve the scopes for the stack frame identified by `frameId`. The `frameId` must have been obtained in the current suspended state. See 'Lifetime of Object References' in the Overview section for details.
  """

  typedstruct do
    @typedoc "A type defining DAP structure ScopesArguments"
    field(:frame_id, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"frameId", :frame_id} => int()
    })
  end
end
