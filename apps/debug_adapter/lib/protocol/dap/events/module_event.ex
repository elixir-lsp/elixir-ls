# codegen: do not edit

defmodule GenDAP.Events.ModuleEvent do
  @moduledoc """
  The event indicates that some information about a module has changed.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "module"
    field :body, %{module: GenDAP.Structures.Module.t(), reason: String.t()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "module",
      :body => map(%{
        :module => GenDAP.Structures.Module.schematic(),
        :reason => oneof(["new", "changed", "removed"])
      })
    })
  end
end
