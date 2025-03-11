# codegen: do not edit
defmodule GenDAP.Requests.Initialize do
  @moduledoc """
  The `initialize` request is sent as the first request from the client to the debug adapter in order to configure it with client capabilities and to retrieve capabilities from the debug adapter.
  Until the debug adapter has responded with an `initialize` response, the client must not send any additional requests or events to the debug adapter.
  In addition the debug adapter is not allowed to send any requests or events to the client until it has responded with an `initialize` response.
  The `initialize` request may only be sent once.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "initialize"
    field :arguments, GenDAP.Structures.InitializeRequestArguments.t()
  end

  @type response :: GenDAP.Structures.Capabilities.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "initialize",
      :arguments => GenDAP.Structures.InitializeRequestArguments.schematic()
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
      :command => "initialize",
      optional(:message) => str(),
      optional(:body) => GenDAP.Structures.Capabilities.schematic()
    })
  end
end
