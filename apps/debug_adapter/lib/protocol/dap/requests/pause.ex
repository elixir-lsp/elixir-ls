# codegen: do not edit
defmodule GenDAP.Requests.Pause do
  @moduledoc """
  The request suspends the debuggee.
  The debug adapter first sends the response and then a `stopped` event (with reason `pause`) after the thread has been paused successfully.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "pause"
    field :arguments, GenDAP.Structures.PauseArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "pause",
      :arguments => GenDAP.Structures.PauseArguments.schematic()
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
      :command => "pause",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
