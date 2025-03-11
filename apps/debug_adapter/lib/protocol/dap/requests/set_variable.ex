# codegen: do not edit
defmodule GenDAP.Requests.SetVariable do
  @moduledoc """
  Set the variable with the given name in the variable container to a new value. Clients should only call this request if the corresponding capability `supportsSetVariable` is true.
  If a debug adapter implements both `setVariable` and `setExpression`, a client will only use `setExpression` if the variable has an `evaluateName` property.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "setVariable"
    field :arguments, GenDAP.Structures.SetVariableArguments.t()
  end

  @type response :: %{type: String.t(), value: String.t(), variables_reference: integer(), memory_reference: String.t(), named_variables: integer(), indexed_variables: integer(), value_location_reference: integer()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setVariable",
      :arguments => GenDAP.Structures.SetVariableArguments.schematic()
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
      :command => "setVariable",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:type) => str(),
      :value => str(),
      optional(:variablesReference) => int(),
      optional(:memoryReference) => str(),
      optional(:namedVariables) => int(),
      optional(:indexedVariables) => int(),
      optional(:valueLocationReference) => int()
    })
    })
  end
end
