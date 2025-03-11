# codegen: do not edit

defmodule GenDAP.Events.BreakpointEvent do
  @moduledoc """
  The event indicates that some information about a breakpoint has changed.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "breakpoint"
    field :body, %{breakpoint: GenDAP.Structures.Breakpoint.t(), reason: String.t()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "breakpoint",
      :body => map(%{
        :breakpoint => GenDAP.Structures.Breakpoint.schematic(),
        :reason => oneof(["changed", "new", "removed"])
      })
    })
  end
end
