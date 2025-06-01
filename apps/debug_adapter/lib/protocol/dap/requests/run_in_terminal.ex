# codegen: do not edit
defmodule GenDAP.Requests.RunInTerminalRequest do
  @moduledoc """
  This request is sent from the debug adapter to the client to run a command in a terminal.
  This is typically used to launch the debuggee in a terminal provided by the client.
  This request should only be called if the corresponding client capability `supportsRunInTerminalRequest` is true.
  Client implementations of `runInTerminal` are free to run the command however they choose including issuing the command to a command line interpreter (aka 'shell'). Argument strings passed to the `runInTerminal` request must arrive verbatim in the command to be run. As a consequence, clients which use a shell are responsible for escaping any special shell characters in the argument strings to prevent them from being interpreted (and modified) by the shell.
  Some users may wish to take advantage of shell processing in the argument strings. For clients which implement `runInTerminal` using an intermediary shell, the `argsCanBeInterpretedByShell` property can be set to true. In this case the client is requested not to escape any special shell characters in the argument strings.

  Message Direction: adapter -> client
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
    @typedoc "A type defining DAP request runInTerminal"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "runInTerminal")
    field(:arguments, GenDAP.Structures.RunInTerminalRequestArguments.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "runInTerminal",
      :arguments => GenDAP.Structures.RunInTerminalRequestArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.RunInTerminalResponse do
  @moduledoc """
  Response to `runInTerminal` request.

  Message Direction: client -> adapter
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
    @typedoc "A type defining DAP request runInTerminal response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "runInTerminal")

    field(:body, %{optional(:process_id) => integer(), optional(:shell_process_id) => integer()},
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
      :command => "runInTerminal",
      :body =>
        map(%{
          optional({"processId", :process_id}) => int(),
          optional({"shellProcessId", :shell_process_id}) => int()
        })
    })
  end
end
