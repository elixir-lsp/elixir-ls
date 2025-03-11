# codegen: do not edit

defmodule GenDAP.Events.OutputEvent do
  @moduledoc """
  The event indicates that the target has produced some output.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "output"
    field :body, %{data: list() | boolean() | integer() | nil | number() | map() | String.t(), line: integer(), output: String.t(), group: String.t(), column: integer(), category: String.t(), source: GenDAP.Structures.Source.t(), variables_reference: integer(), location_reference: integer()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "output",
      :body => map(%{
        optional(:data) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
        optional(:line) => int(),
        :output => str(),
        optional(:group) => oneof(["start", "startCollapsed", "end"]),
        optional(:column) => int(),
        optional(:category) => oneof(["console", "important", "stdout", "stderr", "telemetry"]),
        optional(:source) => GenDAP.Structures.Source.schematic(),
        optional({:variablesReference, :variables_reference}) => int(),
        optional({:locationReference, :location_reference}) => int()
      })
    })
  end
end
