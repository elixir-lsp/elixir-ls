# codegen: do not edit
defmodule GenDAP.Requests.Variables do
  @moduledoc """
  Retrieves all child variables for the given variable reference.
  A filter can be used to limit the fetched children to either named or indexed children.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "variables"
    field :arguments, GenDAP.Structures.VariablesArguments.t()
  end

  @type response :: %{variables: list(GenDAP.Structures.Variable.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "variables",
      :arguments => GenDAP.Structures.VariablesArguments.schematic()
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
      :command => "variables",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :variables => list(GenDAP.Structures.Variable.schematic())
    })
    })
  end
end
