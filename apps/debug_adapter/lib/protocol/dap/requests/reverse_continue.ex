# codegen: do not edit
defmodule GenDAP.Requests.ReverseContinue do
  @moduledoc """
  The request resumes backward execution of all threads. If the debug adapter supports single thread execution (see capability `supportsSingleThreadExecutionRequests`), setting the `singleThread` argument to true resumes only the specified thread. If not all threads were resumed, the `allThreadsContinued` attribute of the response should be set to false.
  Clients should only call this request if the corresponding capability `supportsStepBack` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "reverseContinue"
    field :arguments, GenDAP.Structures.ReverseContinueArguments.t()
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "reverseContinue",
      :arguments => GenDAP.Structures.ReverseContinueArguments.schematic()
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
      :command => "reverseContinue",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
