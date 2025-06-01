# codegen: do not edit

defmodule GenDAP.Events.InitializedEvent do
  @moduledoc """
  This event indicates that the debug adapter is ready to accept configuration requests (e.g. `setBreakpoints`, `setExceptionBreakpoints`).
  A debug adapter is expected to send this event when it is ready to accept configuration requests (but not before the `initialize` request has finished).
  The sequence of events/requests is as follows:
  - adapters sends `initialized` event (after the `initialize` request has returned)
  - client sends zero or more `setBreakpoints` requests
  - client sends one `setFunctionBreakpoints` request (if corresponding capability `supportsFunctionBreakpoints` is true)
  - client sends a `setExceptionBreakpoints` request if one or more `exceptionBreakpointFilters` have been defined (or if `supportsConfigurationDoneRequest` is not true)
  - client sends other future configuration requests
  - client sends one `configurationDone` request to indicate the end of the configuration.

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
    @typedoc "A type defining DAP event initialized"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "initialized")

    field(:body, list() | boolean() | integer() | nil | number() | map() | String.t(),
      enforce: false
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "initialized",
      optional(:body) =>
        oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()])
    })
  end
end
