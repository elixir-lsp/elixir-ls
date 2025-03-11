# codegen: do not edit
defmodule GenDAP.Requests.SetExceptionBreakpoints do
  @moduledoc """
  The request configures the debugger's response to thrown exceptions. Each of the `filters`, `filterOptions`, and `exceptionOptions` in the request are independent configurations to a debug adapter indicating a kind of exception to catch. An exception thrown in a program should result in a `stopped` event from the debug adapter (with reason `exception`) if any of the configured filters match.
  Clients should only call this request if the corresponding capability `exceptionBreakpointFilters` returns one or more filters.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "setExceptionBreakpoints"
    field :arguments, GenDAP.Structures.SetExceptionBreakpointsArguments.t()
  end

  @type response :: %{breakpoints: list(GenDAP.Structures.Breakpoint.t())}

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

  @doc false
  @spec response() :: Schematic.t()
  def response() do
    schema(GenDAP.Response, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => bool(),
      :command => "setExceptionBreakpoints",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:breakpoints) => list(GenDAP.Structures.Breakpoint.schematic())
    })
    })
  end
end
