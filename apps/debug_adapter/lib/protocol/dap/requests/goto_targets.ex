# codegen: do not edit
defmodule GenDAP.Requests.GotoTargets do
  @moduledoc """
  This request retrieves the possible goto targets for the specified source location.
  These targets can be used in the `goto` request.
  Clients should only call this request if the corresponding capability `supportsGotoTargetsRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "gotoTargets"
    field :arguments, GenDAP.Structures.GotoTargetsArguments.t()
  end

  @type response :: %{targets: list(GenDAP.Structures.GotoTarget.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "gotoTargets",
      :arguments => GenDAP.Structures.GotoTargetsArguments.schematic()
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
      :command => "gotoTargets",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :targets => list(GenDAP.Structures.GotoTarget.schematic())
    })
    })
  end
end
