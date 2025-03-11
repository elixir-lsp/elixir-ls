# codegen: do not edit

defmodule GenDAP.Events.TerminatedEvent do
  @moduledoc """
  The event indicates that debugging of the debuggee has terminated. This does **not** mean that the debuggee itself has exited.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "terminated"
    field :body, %{restart: list() | boolean() | integer() | nil | number() | map() | String.t()}, enforce: false
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "terminated",
      optional(:body) => map(%{
        optional(:restart) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()])
      })
    })
  end
end
