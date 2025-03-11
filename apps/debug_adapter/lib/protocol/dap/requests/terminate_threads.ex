# codegen: do not edit
defmodule GenDAP.Requests.TerminateThreads do
  @moduledoc """
  The request terminates the threads with the given ids.
  Clients should only call this request if the corresponding capability `supportsTerminateThreadsRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "terminateThreads"
    field :arguments, GenDAP.Structures.TerminateThreadsArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "terminateThreads",
      :arguments => GenDAP.Structures.TerminateThreadsArguments.schematic()
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
      :command => "terminateThreads",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
