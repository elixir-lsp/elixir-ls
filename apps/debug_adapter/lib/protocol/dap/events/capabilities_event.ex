# codegen: do not edit

defmodule GenDAP.Events.CapabilitiesEvent do
  @moduledoc """
  The event indicates that one or more capabilities have changed.
  Since the capabilities are dependent on the client and its UI, it might not be possible to change that at random times (or too late).
  Consequently this event has a hint characteristic: a client can only be expected to make a 'best effort' in honoring individual capabilities but there are no guarantees.
  Only changed capabilities need to be included, all other capabilities keep their values.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "capabilities"
    field :body, %{capabilities: GenDAP.Structures.Capabilities.t()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "capabilities",
      :body => map(%{
        :capabilities => GenDAP.Structures.Capabilities.schematic()
      })
    })
  end
end
