# codegen: do not edit

defmodule GenDAP.Events.MemoryEvent do
  @moduledoc """
  This event indicates that some memory range has been updated. It should only be sent if the corresponding capability `supportsMemoryEvent` is true.
  Clients typically react to the event by re-issuing a `readMemory` request if they show the memory identified by the `memoryReference` and if the updated memory range overlaps the displayed range. Clients should not make assumptions how individual memory references relate to each other, so they should not assume that they are part of a single continuous address range and might overlap.
  Debug adapters can use this event to indicate that the contents of a memory range has changed due to some other request like `setVariable` or `setExpression`. Debug adapters are not expected to emit this event for each and every memory change of a running program, because that information is typically not available from debuggers and it would flood clients with too many events.

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
    @typedoc "A type defining DAP event memory"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "memory")

    field(
      :body,
      %{
        required(:count) => integer(),
        required(:offset) => integer(),
        required(:memory_reference) => String.t()
      },
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "memory",
      :body =>
        map(%{
          {"count", :count} => int(),
          {"offset", :offset} => int(),
          {"memoryReference", :memory_reference} => str()
        })
    })
  end
end
