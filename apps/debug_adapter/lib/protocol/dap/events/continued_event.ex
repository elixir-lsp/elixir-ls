# codegen: do not edit

defmodule GenDAP.Events.ContinuedEvent do
  @moduledoc """
  The event indicates that the execution of the debuggee has continued.
  Please note: a debug adapter is not expected to send this event in response to a request that implies that execution continues, e.g. `launch` or `continue`.
  It is only necessary to send a `continued` event if there was no previous request that implied this.

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
    @typedoc "A type defining DAP event continued"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "continued")

    field(
      :body,
      %{required(:thread_id) => integer(), optional(:all_threads_continued) => boolean()},
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "continued",
      :body =>
        map(%{
          {"threadId", :thread_id} => int(),
          optional({"allThreadsContinued", :all_threads_continued}) => bool()
        })
    })
  end
end
