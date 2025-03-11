# codegen: do not edit
defmodule GenDAP.Requests.StepIn do
  @moduledoc """
  The request resumes the given thread to step into a function/method and allows all other threads to run freely by resuming them.
  If the debug adapter supports single thread execution (see capability `supportsSingleThreadExecutionRequests`), setting the `singleThread` argument to true prevents other suspended threads from resuming.
  If the request cannot step into a target, `stepIn` behaves like the `next` request.
  The debug adapter first sends the response and then a `stopped` event (with reason `step`) after the step has completed.
  If there are multiple function/method calls (or other targets) on the source line,
  the argument `targetId` can be used to control into which target the `stepIn` should occur.
  The list of possible targets for a given source line can be retrieved via the `stepInTargets` request.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "stepIn"
    field :arguments, GenDAP.Structures.StepInArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "stepIn",
      :arguments => GenDAP.Structures.StepInArguments.schematic()
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
      :command => "stepIn",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
