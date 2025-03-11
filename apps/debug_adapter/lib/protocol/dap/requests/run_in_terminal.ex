# codegen: do not edit
defmodule GenDAP.Requests.RunInTerminal do
  @moduledoc """
  This request is sent from the debug adapter to the client to run a command in a terminal.
  This is typically used to launch the debuggee in a terminal provided by the client.
  This request should only be called if the corresponding client capability `supportsRunInTerminalRequest` is true.
  Client implementations of `runInTerminal` are free to run the command however they choose including issuing the command to a command line interpreter (aka 'shell'). Argument strings passed to the `runInTerminal` request must arrive verbatim in the command to be run. As a consequence, clients which use a shell are responsible for escaping any special shell characters in the argument strings to prevent them from being interpreted (and modified) by the shell.
  Some users may wish to take advantage of shell processing in the argument strings. For clients which implement `runInTerminal` using an intermediary shell, the `argsCanBeInterpretedByShell` property can be set to true. In this case the client is requested not to escape any special shell characters in the argument strings.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "runInTerminal"
    field :arguments, GenDAP.Structures.RunInTerminalRequestArguments.t()
  end

  @type response :: %{process_id: integer(), shell_process_id: integer()}

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

  @doc false
  @spec response() :: Schematic.t()
  def response() do
    schema(GenDAP.Response, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => bool(),
      :command => "runInTerminal",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:processId) => int(),
      optional(:shellProcessId) => int()
    })
    })
  end
end
