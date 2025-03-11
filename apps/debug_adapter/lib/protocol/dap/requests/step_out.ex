# codegen: do not edit
defmodule GenDAP.Requests.StepOut do
  @moduledoc """
  The request resumes the given thread to step out (return) from a function/method and allows all other threads to run freely by resuming them.
  If the debug adapter supports single thread execution (see capability `supportsSingleThreadExecutionRequests`), setting the `singleThread` argument to true prevents other suspended threads from resuming.
  The debug adapter first sends the response and then a `stopped` event (with reason `step`) after the step has completed.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "stepOut"
    field :arguments, GenDAP.Structures.StepOutArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "stepOut",
      :arguments => GenDAP.Structures.StepOutArguments.schematic()
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
      :command => "stepOut",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
