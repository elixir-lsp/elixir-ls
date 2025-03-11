# codegen: do not edit
defmodule GenDAP.Requests.StepInTargets do
  @moduledoc """
  This request retrieves the possible step-in targets for the specified stack frame.
  These targets can be used in the `stepIn` request.
  Clients should only call this request if the corresponding capability `supportsStepInTargetsRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "stepInTargets"
    field :arguments, GenDAP.Structures.StepInTargetsArguments.t()
  end

  @type response :: %{targets: list(GenDAP.Structures.StepInTarget.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "stepInTargets",
      :arguments => GenDAP.Structures.StepInTargetsArguments.schematic()
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
      :command => "stepInTargets",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :targets => list(GenDAP.Structures.StepInTarget.schematic())
    })
    })
  end
end
