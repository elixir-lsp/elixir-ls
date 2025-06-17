# codegen: do not edit

defmodule GenDAP.Events.CapabilitiesEvent do
  @moduledoc """
  The event indicates that one or more capabilities have changed.
  Since the capabilities are dependent on the client and its UI, it might not be possible to change that at random times (or too late).
  Consequently this event has a hint characteristic: a client can only be expected to make a 'best effort' in honoring individual capabilities but there are no guarantees.
  Only changed capabilities need to be included, all other capabilities keep their values.

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
    @typedoc "A type defining DAP event capabilities"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "capabilities")
    field(:body, %{required(:capabilities) => GenDAP.Structures.Capabilities.t()}, enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "capabilities",
      :body =>
        map(%{
          {"capabilities", :capabilities} => GenDAP.Structures.Capabilities.schematic()
        })
    })
  end
end
