# codegen: do not edit

defmodule GenDAP.Events.InvalidatedEvent do
  @moduledoc """
  This event signals that some state in the debug adapter has changed and requires that the client needs to re-render the data snapshot previously requested.
  Debug adapters do not have to emit this event for runtime changes like stopped or thread events because in that case the client refetches the new state anyway. But the event can be used for example to refresh the UI after rendering formatting has changed in the debug adapter.
  This event should only be sent if the corresponding capability `supportsInvalidatedEvent` is true.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "invalidated"
    field :body, %{thread_id: integer(), areas: list(GenDAP.Enumerations.InvalidatedAreas.t()), stack_frame_id: integer()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "invalidated",
      :body => map(%{
        optional({:threadId, :thread_id}) => int(),
        optional(:areas) => list(GenDAP.Enumerations.InvalidatedAreas.schematic()),
        optional({:stackFrameId, :stack_frame_id}) => int()
      })
    })
  end
end
