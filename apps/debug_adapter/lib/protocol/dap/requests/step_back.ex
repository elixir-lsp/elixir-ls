# codegen: do not edit
defmodule GenDAP.Requests.StepBack do
  @moduledoc """
  The request executes one backward step (in the given granularity) for the specified thread and allows all other threads to run backward freely by resuming them.
  If the debug adapter supports single thread execution (see capability `supportsSingleThreadExecutionRequests`), setting the `singleThread` argument to true prevents other suspended threads from resuming.
  The debug adapter first sends the response and then a `stopped` event (with reason `step`) after the step has completed.
  Clients should only call this request if the corresponding capability `supportsStepBack` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "stepBack"
    field :arguments, GenDAP.Structures.StepBackArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "stepBack",
      :arguments => GenDAP.Structures.StepBackArguments.schematic()
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
      :command => "stepBack",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
