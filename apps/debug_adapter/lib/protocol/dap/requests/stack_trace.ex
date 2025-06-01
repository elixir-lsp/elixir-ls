# codegen: do not edit
defmodule GenDAP.Requests.StackTraceRequest do
  @moduledoc """
  The request returns a stacktrace from the current execution state of a given thread.
  A client can request all stack frames by omitting the startFrame and levels arguments. For performance-conscious clients and if the corresponding capability `supportsDelayedStackTraceLoading` is true, stack frames can be retrieved in a piecemeal way with the `startFrame` and `levels` arguments. The response of the `stackTrace` request may contain a `totalFrames` property that hints at the total number of frames in the stack. If a client needs this total number upfront, it can issue a request for a single (first) frame and depending on the value of `totalFrames` decide how to proceed. In any case a client should be prepared to receive fewer frames than requested, which is an indication that the end of the stack has been reached.

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
    @typedoc "A type defining DAP request stackTrace"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "stackTrace")
    field(:arguments, GenDAP.Structures.StackTraceArguments.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "stackTrace",
      :arguments => GenDAP.Structures.StackTraceArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.StackTraceResponse do
  @moduledoc """
  Response to `stackTrace` request.

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
    @typedoc "A type defining DAP request stackTrace response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "stackTrace")

    field(
      :body,
      %{
        required(:stack_frames) => list(GenDAP.Structures.StackFrame.t()),
        optional(:total_frames) => integer()
      },
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => true,
      :command => "stackTrace",
      :body =>
        map(%{
          {"stackFrames", :stack_frames} => list(GenDAP.Structures.StackFrame.schematic()),
          optional({"totalFrames", :total_frames}) => int()
        })
    })
  end
end
