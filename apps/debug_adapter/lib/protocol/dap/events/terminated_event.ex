# codegen: do not edit

defmodule GenDAP.Events.TerminatedEvent do
  @moduledoc """
  The event indicates that debugging of the debuggee has terminated. This does **not** mean that the debuggee itself has exited.

  Message Direction: adapter -> client
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * body: Event-specific information.
  * event: Type of event.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """

  typedstruct do
    @typedoc "A type defining DAP event terminated"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "terminated")

    field(
      :body,
      %{
        optional(:restart) => list() | boolean() | integer() | nil | number() | map() | String.t()
      },
      enforce: false
    )
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "terminated",
      optional(:body) =>
        map(%{
          optional({"restart", :restart}) =>
            oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()])
        })
    })
  end
end
