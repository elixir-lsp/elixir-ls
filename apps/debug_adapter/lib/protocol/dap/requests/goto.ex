# codegen: do not edit
defmodule GenDAP.Requests.Goto do
  @moduledoc """
  The request sets the location where the debuggee will continue to run.
  This makes it possible to skip the execution of code or to execute code again.
  The code between the current location and the goto target is not executed but skipped.
  The debug adapter first sends the response and then a `stopped` event with reason `goto`.
  Clients should only call this request if the corresponding capability `supportsGotoTargetsRequest` is true (because only then goto targets exist that can be passed as arguments).

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "goto"
    field :arguments, GenDAP.Structures.GotoArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "goto",
      :arguments => GenDAP.Structures.GotoArguments.schematic()
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
      :command => "goto",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
