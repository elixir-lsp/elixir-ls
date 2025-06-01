# codegen: do not edit

defmodule GenDAP.Events.ProgressStartEvent do
  @moduledoc """
  The event signals that a long running operation is about to start and provides additional information for the client to set up a corresponding progress and cancellation UI.
  The client is free to delay the showing of the UI in order to reduce flicker.
  This event should only be sent if the corresponding capability `supportsProgressReporting` is true.

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

  typedstruct do
    @typedoc "A type defining DAP event progressStart"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "progressStart")

    field(
      :body,
      %{
        optional(:message) => String.t(),
        required(:title) => String.t(),
        optional(:request_id) => integer(),
        required(:progress_id) => String.t(),
        optional(:cancellable) => boolean(),
        optional(:percentage) => number()
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
      :event => "progressStart",
      :body =>
        map(%{
          optional({"message", :message}) => str(),
          {"title", :title} => str(),
          optional({"requestId", :request_id}) => int(),
          {"progressId", :progress_id} => str(),
          optional({"cancellable", :cancellable}) => bool(),
          optional({"percentage", :percentage}) => oneof([int(), float()])
        })
    })
  end
end
