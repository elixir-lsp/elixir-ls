# codegen: do not edit
defmodule GenDAP.Requests.Restart do
  @moduledoc """
  Restarts a debug session. Clients should only call this request if the corresponding capability `supportsRestartRequest` is true.
  If the capability is missing or has the value false, a typical client emulates `restart` by terminating the debug adapter first and then launching it anew.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "restart"
    field :arguments, GenDAP.Structures.RestartArguments.t(), enforce: false
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "restart",
      optional(:arguments) => GenDAP.Structures.RestartArguments.schematic()
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
      :command => "restart",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
