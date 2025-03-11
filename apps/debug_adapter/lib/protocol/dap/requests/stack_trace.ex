# codegen: do not edit
defmodule GenDAP.Requests.StackTrace do
  @moduledoc """
  The request returns a stacktrace from the current execution state of a given thread.
  A client can request all stack frames by omitting the startFrame and levels arguments. For performance-conscious clients and if the corresponding capability `supportsDelayedStackTraceLoading` is true, stack frames can be retrieved in a piecemeal way with the `startFrame` and `levels` arguments. The response of the `stackTrace` request may contain a `totalFrames` property that hints at the total number of frames in the stack. If a client needs this total number upfront, it can issue a request for a single (first) frame and depending on the value of `totalFrames` decide how to proceed. In any case a client should be prepared to receive fewer frames than requested, which is an indication that the end of the stack has been reached.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "stackTrace"
    field :arguments, GenDAP.Structures.StackTraceArguments.t()
  end

  @type response :: %{stack_frames: list(GenDAP.Structures.StackFrame.t()), total_frames: integer()}

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

  @doc false
  @spec response() :: Schematic.t()
  def response() do
    schema(GenDAP.Response, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => bool(),
      :command => "stackTrace",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :stackFrames => list(GenDAP.Structures.StackFrame.schematic()),
      optional(:totalFrames) => int()
    })
    })
  end
end
