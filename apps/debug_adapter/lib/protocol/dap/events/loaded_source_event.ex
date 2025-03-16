# codegen: do not edit

defmodule GenDAP.Events.LoadedSourceEvent do
  @moduledoc """
  The event indicates that some source has been added, changed, or removed from the set of all loaded sources.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * body: Event-specific information.
  * event: Type of event.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP event loadedSource"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "loadedSource")

    field(
      :body,
      %{required(:reason) => String.t(), required(:source) => GenDAP.Structures.Source.t()},
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "loadedSource",
      :body =>
        map(%{
          {"reason", :reason} => oneof(["new", "changed", "removed"]),
          {"source", :source} => GenDAP.Structures.Source.schematic()
        })
    })
  end
end
