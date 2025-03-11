# codegen: do not edit
defmodule GenDAP.Requests.Locations do
  @moduledoc """
  Looks up information about a location reference previously returned by the debug adapter.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "locations"
    field :arguments, GenDAP.Structures.LocationsArguments.t()
  end

  @type response :: %{line: integer(), column: integer(), source: GenDAP.Structures.Source.t(), end_line: integer(), end_column: integer()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "locations",
      :arguments => GenDAP.Structures.LocationsArguments.schematic()
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
      :command => "locations",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :line => int(),
      optional(:column) => int(),
      :source => GenDAP.Structures.Source.schematic(),
      optional(:endLine) => int(),
      optional(:endColumn) => int()
    })
    })
  end
end
