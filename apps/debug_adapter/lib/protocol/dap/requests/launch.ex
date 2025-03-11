# codegen: do not edit
defmodule GenDAP.Requests.Launch do
  @moduledoc """
  This launch request is sent from the client to the debug adapter to start the debuggee with or without debugging (if `noDebug` is true).
  Since launching is debugger/runtime specific, the arguments for this request are not part of this specification.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "launch"
    field :arguments, GenDAP.Structures.LaunchRequestArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "launch",
      :arguments => GenDAP.Structures.LaunchRequestArguments.schematic()
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
      :command => "launch",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
