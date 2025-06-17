# codegen: do not edit
defmodule GenDAP.Requests.StepInRequest do
  @moduledoc """
  The request resumes the given thread to step into a function/method and allows all other threads to run freely by resuming them.
  If the debug adapter supports single thread execution (see capability `supportsSingleThreadExecutionRequests`), setting the `singleThread` argument to true prevents other suspended threads from resuming.
  If the request cannot step into a target, `stepIn` behaves like the `next` request.
  The debug adapter first sends the response and then a `stopped` event (with reason `step`) after the step has completed.
  If there are multiple function/method calls (or other targets) on the source line,
  the argument `targetId` can be used to control into which target the `stepIn` should occur.
  The list of possible targets for a given source line can be retrieved via the `stepInTargets` request.

  Message Direction: client -> adapter
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * arguments: Object containing arguments for the command.
  * command: The command to execute.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """

  typedstruct do
    @typedoc "A type defining DAP request stepIn"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "stepIn")
    field(:arguments, GenDAP.Structures.StepInArguments.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "stepIn",
      :arguments => GenDAP.Structures.StepInArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.StepInResponse do
  @moduledoc """
  A response to the stepIn request

  Message Direction: adapter -> client
  """

  import SchematicV, warn: false

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
    @typedoc "A type defining DAP request stepIn response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "stepIn")
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => true,
      :command => "stepIn"
    })
  end
end
