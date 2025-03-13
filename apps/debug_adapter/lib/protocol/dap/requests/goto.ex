# codegen: do not edit
defmodule GenDAP.Requests.GotoRequest do
  @moduledoc """
  The request sets the location where the debuggee will continue to run.
  This makes it possible to skip the execution of code or to execute code again.
  The code between the current location and the goto target is not executed but skipped.
  The debug adapter first sends the response and then a `stopped` event with reason `goto`.
  Clients should only call this request if the corresponding capability `supportsGotoTargetsRequest` is true (because only then goto targets exist that can be passed as arguments).

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
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP request goto"

    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "goto"
    field :arguments, GenDAP.Structures.GotoArguments.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "goto",
      :arguments => GenDAP.Structures.GotoArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.GotoResponse do
  @moduledoc """
  A response to the goto request

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
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP request goto response"

    field :seq, integer(), enforce: true
    field :type, String.t(), default: "response"
    field :request_seq, integer(), enforce: true
    field :success, boolean(), default: true
    field :command, String.t(), default: "goto"
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => true,
      :command => "goto",
    })
  end
end
