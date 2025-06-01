# codegen: do not edit
defmodule GenDAP.Requests.CancelRequest do
  @moduledoc """
  The `cancel` request is used by the client in two situations:
  - to indicate that it is no longer interested in the result produced by a specific request issued earlier
  - to cancel a progress sequence.
  Clients should only call this request if the corresponding capability `supportsCancelRequest` is true.
  This request has a hint characteristic: a debug adapter can only be expected to make a 'best effort' in honoring this request but there are no guarantees.
  The `cancel` request may return an error if it could not cancel an operation but a client should refrain from presenting this error to end users.
  The request that got cancelled still needs to send a response back. This can either be a normal result (`success` attribute true) or an error response (`success` attribute false and the `message` set to `cancelled`).
  Returning partial results from a cancelled request is possible but please note that a client has no generic way for detecting that a response is partial or not.
  The progress that got cancelled still needs to send a `progressEnd` event back.
   A client should not assume that progress just got cancelled after sending the `cancel` request.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * arguments: Object containing arguments for the command.
  * command: The command to execute.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """

  typedstruct do
    @typedoc "A type defining DAP request cancel"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "cancel")
    field(:arguments, GenDAP.Structures.CancelArguments.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "cancel",
      optional(:arguments) => GenDAP.Structures.CancelArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.CancelResponse do
  @moduledoc """
  A response to the cancel request

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * body: Contains request result if success is true and error details if success is false.
  * command: The command requested.
  * message: Contains the raw error in short form if `success` is false.
    This raw error might be interpreted by the client and is not shown in the UI.
    Some predefined values exist.
  * request_seq: Sequence number of the corresponding request.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * success: Outcome of the request.
    If true, the request was successful and the `body` attribute may contain the result of the request.
    If the value is false, the attribute `message` contains the error in short form and the `body` may contain additional information (see `ErrorResponse.body.error`).
  * type: Message type.
  """

  typedstruct do
    @typedoc "A type defining DAP request cancel response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "cancel")
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => true,
      :command => "cancel"
    })
  end
end
