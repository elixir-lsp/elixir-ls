# codegen: do not edit

defmodule GenDAP.Events.ThreadEvent do
  @moduledoc """
  The event indicates that a thread has started or exited.

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
    @typedoc "A type defining DAP event thread"

    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "thread"
    field :body, %{required(:reason) => String.t(), required(:thread_id) => integer()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "thread",
      :body => map(%{
        {"reason", :reason} => oneof(["started", "exited", str()]),
        {"threadId", :thread_id} => int()
      })
    })
  end
end
