# codegen: do not edit

defmodule GenDAP.Notifications.BreakpointEvent do

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "breakpoint"
    field :body, %{breakpoint: GenDAP.Structures.Breakpoint.t(), reason: String.t()}, enforce: false
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "breakpoint",
      optional(:body) => map(%{
        :breakpoint => GenDAP.Structures.Breakpoint.schematic(),
        :reason => str()
      })
    })
  end
end
