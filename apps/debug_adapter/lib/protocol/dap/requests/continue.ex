# codegen: do not edit
defmodule GenDAP.Requests.Continue do
  @moduledoc """
  The request resumes execution of all threads. If the debug adapter supports single thread execution (see capability `supportsSingleThreadExecutionRequests`), setting the `singleThread` argument to true resumes only the specified thread. If not all threads were resumed, the `allThreadsContinued` attribute of the response should be set to false.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "continue"
    field :arguments, GenDAP.Structures.ContinueArguments.t()
  end

  @type response :: %{all_threads_continued: boolean()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "continue",
      :arguments => GenDAP.Structures.ContinueArguments.schematic()
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
      :command => "continue",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:allThreadsContinued) => bool()
    })
    })
  end
end
