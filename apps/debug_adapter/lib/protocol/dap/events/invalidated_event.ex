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

  @doc """
  ## Fields
  
  * body: Event-specific information.
  * event: Type of event.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP event invalidated"

    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "invalidated"
    field :body, %{optional(:thread_id) => integer(), optional(:areas) => list(GenDAP.Enumerations.InvalidatedAreas.t()), optional(:stack_frame_id) => integer()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "invalidated",
      :body => map(%{
        optional({"threadId", :thread_id}) => int(),
        optional({"areas", :areas}) => list(GenDAP.Enumerations.InvalidatedAreas.schematic()),
        optional({"stackFrameId", :stack_frame_id}) => int()
      })
    })
  end
end
