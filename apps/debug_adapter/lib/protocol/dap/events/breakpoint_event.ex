# codegen: do not edit

defmodule GenDAP.Events.BreakpointEvent do
  @moduledoc """
  The event indicates that some information about a breakpoint has changed.

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
    @typedoc "A type defining DAP event breakpoint"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "breakpoint")

    field(
      :body,
      %{
        required(:breakpoint) => GenDAP.Structures.Breakpoint.t(),
        required(:reason) => String.t()
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
      :event => "breakpoint",
      :body =>
        map(%{
          {"breakpoint", :breakpoint} => GenDAP.Structures.Breakpoint.schematic(),
          {"reason", :reason} => oneof(["changed", "new", "removed", str()])
        })
    })
  end
end
