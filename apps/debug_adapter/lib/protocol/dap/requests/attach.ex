# codegen: do not edit
defmodule GenDAP.Requests.Attach do
  @moduledoc """
  The `attach` request is sent from the client to the debug adapter to attach to a debuggee that is already running.
  Since attaching is debugger/runtime specific, the arguments for this request are not part of this specification.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "attach"
    field :arguments, GenDAP.Structures.AttachRequestArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "attach",
      :arguments => GenDAP.Structures.AttachRequestArguments.schematic()
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
      :command => "attach",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
