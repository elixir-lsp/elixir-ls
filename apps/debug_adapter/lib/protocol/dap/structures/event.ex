# codegen: do not edit
defmodule GenDAP.Structures.Event do
  @moduledoc """
  A debug adapter initiated event.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * type
  * body: Event-specific information.
  * event: Type of event.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :type, String.t(), enforce: true
    field :body, list() | boolean() | integer() | nil | number() | map() | String.t()
    field :event, String.t(), enforce: true
    field :seq, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"type", :type} => oneof(["event"]),
      optional({"body", :body}) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
      {"event", :event} => str(),
      {"seq", :seq} => int(),
    })
  end
end
