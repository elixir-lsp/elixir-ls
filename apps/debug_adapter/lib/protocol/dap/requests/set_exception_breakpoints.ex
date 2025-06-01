# codegen: do not edit
defmodule GenDAP.Requests.SetExceptionBreakpointsRequest do
  @moduledoc """
  The request configures the debugger's response to thrown exceptions. Each of the `filters`, `filterOptions`, and `exceptionOptions` in the request are independent configurations to a debug adapter indicating a kind of exception to catch. An exception thrown in a program should result in a `stopped` event from the debug adapter (with reason `exception`) if any of the configured filters match.
  Clients should only call this request if the corresponding capability `exceptionBreakpointFilters` returns one or more filters.

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
    @typedoc "A type defining DAP request setExceptionBreakpoints"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "setExceptionBreakpoints")
    field(:arguments, GenDAP.Structures.SetExceptionBreakpointsArguments.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setExceptionBreakpoints",
      :arguments => GenDAP.Structures.SetExceptionBreakpointsArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.SetExceptionBreakpointsResponse do
  @moduledoc """
  Response to `setExceptionBreakpoints` request.
  The response contains an array of `Breakpoint` objects with information about each exception breakpoint or filter. The `Breakpoint` objects are in the same order as the elements of the `filters`, `filterOptions`, `exceptionOptions` arrays given as arguments. If both `filters` and `filterOptions` are given, the returned array must start with `filters` information first, followed by `filterOptions` information.
  The `verified` property of a `Breakpoint` object signals whether the exception breakpoint or filter could be successfully created and whether the condition is valid. In case of an error the `message` property explains the problem. The `id` property can be used to introduce a unique ID for the exception breakpoint or filter so that it can be updated subsequently by sending breakpoint events.
  For backward compatibility both the `breakpoints` array and the enclosing `body` are optional. If these elements are missing a client is not able to show problems for individual exception breakpoints or filters.

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
    @typedoc "A type defining DAP request setExceptionBreakpoints response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "setExceptionBreakpoints")
    field(:body, %{optional(:breakpoints) => list(GenDAP.Structures.Breakpoint.t())})
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => true,
      :command => "setExceptionBreakpoints",
      optional(:body) =>
        map(%{
          optional({"breakpoints", :breakpoints}) =>
            list(GenDAP.Structures.Breakpoint.schematic())
        })
    })
  end
end
