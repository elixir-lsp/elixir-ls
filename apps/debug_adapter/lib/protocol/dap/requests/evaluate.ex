# codegen: do not edit
defmodule GenDAP.Requests.Evaluate do
  @moduledoc """
  Evaluates the given expression in the context of a stack frame.
  The expression has access to any variables and arguments that are in scope.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "evaluate"
    field :arguments, GenDAP.Structures.EvaluateArguments.t()
  end

  @type response :: %{type: String.t(), result: String.t(), variables_reference: integer(), memory_reference: String.t(), named_variables: integer(), indexed_variables: integer(), value_location_reference: integer(), presentation_hint: GenDAP.Structures.VariablePresentationHint.t()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "evaluate",
      :arguments => GenDAP.Structures.EvaluateArguments.schematic()
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
      :command => "evaluate",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:type) => str(),
      :result => str(),
      :variablesReference => int(),
      optional(:memoryReference) => str(),
      optional(:namedVariables) => int(),
      optional(:indexedVariables) => int(),
      optional(:valueLocationReference) => int(),
      optional(:presentationHint) => GenDAP.Structures.VariablePresentationHint.schematic()
    })
    })
  end
end
