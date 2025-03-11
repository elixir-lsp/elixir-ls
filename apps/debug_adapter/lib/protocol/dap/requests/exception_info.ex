# codegen: do not edit
defmodule GenDAP.Requests.ExceptionInfo do
  @moduledoc """
  Retrieves the details of the exception that caused this event to be raised.
  Clients should only call this request if the corresponding capability `supportsExceptionInfoRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "exceptionInfo"
    field :arguments, GenDAP.Structures.ExceptionInfoArguments.t()
  end

  @type response :: %{description: String.t(), details: GenDAP.Structures.ExceptionDetails.t(), exception_id: String.t(), break_mode: GenDAP.Enumerations.ExceptionBreakMode.t()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "exceptionInfo",
      :arguments => GenDAP.Structures.ExceptionInfoArguments.schematic()
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
      :command => "exceptionInfo",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:description) => str(),
      optional(:details) => GenDAP.Structures.ExceptionDetails.schematic(),
      :exceptionId => str(),
      :breakMode => GenDAP.Enumerations.ExceptionBreakMode.schematic()
    })
    })
  end
end
