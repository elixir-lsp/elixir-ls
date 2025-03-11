# codegen: do not edit

defmodule GenDAP.Events.LoadedSourceEvent do
  @moduledoc """
  The event indicates that some source has been added, changed, or removed from the set of all loaded sources.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "loadedSource"
    field :body, %{reason: String.t(), source: GenDAP.Structures.Source.t()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "loadedSource",
      :body => map(%{
        :reason => oneof(["new", "changed", "removed"]),
        :source => GenDAP.Structures.Source.schematic()
      })
    })
  end
end
