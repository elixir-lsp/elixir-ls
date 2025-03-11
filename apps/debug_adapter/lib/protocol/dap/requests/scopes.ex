# codegen: do not edit
defmodule GenDAP.Requests.Scopes do
  @moduledoc """
  The request returns the variable scopes for a given stack frame ID.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "scopes"
    field :arguments, GenDAP.Structures.ScopesArguments.t()
  end

  @type response :: %{scopes: list(GenDAP.Structures.Scope.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "scopes",
      :arguments => GenDAP.Structures.ScopesArguments.schematic()
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
      :command => "scopes",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :scopes => list(GenDAP.Structures.Scope.schematic())
    })
    })
  end
end
