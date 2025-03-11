# codegen: do not edit
defmodule GenDAP.Requests.SetExpression do
  @moduledoc """
  Evaluates the given `value` expression and assigns it to the `expression` which must be a modifiable l-value.
  The expressions have access to any variables and arguments that are in scope of the specified frame.
  Clients should only call this request if the corresponding capability `supportsSetExpression` is true.
  If a debug adapter implements both `setExpression` and `setVariable`, a client uses `setExpression` if the variable has an `evaluateName` property.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "setExpression"
    field :arguments, GenDAP.Structures.SetExpressionArguments.t()
  end

  @type response :: %{type: String.t(), value: String.t(), variables_reference: integer(), memory_reference: String.t(), named_variables: integer(), indexed_variables: integer(), value_location_reference: integer(), presentation_hint: GenDAP.Structures.VariablePresentationHint.t()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setExpression",
      :arguments => GenDAP.Structures.SetExpressionArguments.schematic()
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
      :command => "setExpression",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:type) => str(),
      :value => str(),
      optional(:variablesReference) => int(),
      optional(:memoryReference) => str(),
      optional(:namedVariables) => int(),
      optional(:indexedVariables) => int(),
      optional(:valueLocationReference) => int(),
      optional(:presentationHint) => GenDAP.Structures.VariablePresentationHint.schematic()
    })
    })
  end
end
