# codegen: do not edit
defmodule GenDAP.Requests.StartDebugging do
  @moduledoc """
  This request is sent from the debug adapter to the client to start a new debug session of the same type as the caller.
  This request should only be sent if the corresponding client capability `supportsStartDebuggingRequest` is true.
  A client implementation of `startDebugging` should start a new debug session (of the same type as the caller) in the same way that the caller's session was started. If the client supports hierarchical debug sessions, the newly created session can be treated as a child of the caller session.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "startDebugging"
    field :arguments, GenDAP.Structures.StartDebuggingRequestArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "startDebugging",
      :arguments => GenDAP.Structures.StartDebuggingRequestArguments.schematic()
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
      :command => "startDebugging",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
