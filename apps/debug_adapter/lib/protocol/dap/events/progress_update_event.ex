# codegen: do not edit

defmodule GenDAP.Events.ProgressUpdateEvent do
  @moduledoc """
  The event signals that the progress reporting needs to be updated with a new message and/or percentage.
  The client does not have to update the UI immediately, but the clients needs to keep track of the message and/or percentage values.
  This event should only be sent if the corresponding capability `supportsProgressReporting` is true.

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
    @typedoc "A type defining DAP event progressUpdate"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "progressUpdate")

    field(
      :body,
      %{
        optional(:message) => String.t(),
        required(:progress_id) => String.t(),
        optional(:percentage) => number()
      },
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "progressUpdate",
      :body =>
        map(%{
          optional({"message", :message}) => str(),
          {"progressId", :progress_id} => str(),
          optional({"percentage", :percentage}) => oneof([int(), float()])
        })
    })
  end
end
