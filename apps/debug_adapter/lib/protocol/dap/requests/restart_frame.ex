# codegen: do not edit
defmodule GenDAP.Requests.RestartFrame do
  @moduledoc """
  The request restarts execution of the specified stack frame.
  The debug adapter first sends the response and then a `stopped` event (with reason `restart`) after the restart has completed.
  Clients should only call this request if the corresponding capability `supportsRestartFrame` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "restartFrame"
    field :arguments, GenDAP.Structures.RestartFrameArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "restartFrame",
      :arguments => GenDAP.Structures.RestartFrameArguments.schematic()
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
      :command => "restartFrame",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
