# codegen: do not edit
defmodule GenDAP.Requests.ConfigurationDone do
  @moduledoc """
  This request indicates that the client has finished initialization of the debug adapter.
  So it is the last request in the sequence of configuration requests (which was started by the `initialized` event).
  Clients should only call this request if the corresponding capability `supportsConfigurationDoneRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "configurationDone"
    field :arguments, GenDAP.Structures.ConfigurationDoneArguments.t(), enforce: false
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "configurationDone",
      optional(:arguments) => GenDAP.Structures.ConfigurationDoneArguments.schematic()
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
      :command => "configurationDone",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
