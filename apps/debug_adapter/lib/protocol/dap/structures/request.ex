# codegen: do not edit
defmodule GenDAP.Structures.Request do
  @moduledoc """
  A client or debug adapter initiated request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * command: The command to execute.
  * type
  * arguments: Object containing arguments for the command.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :command, String.t(), enforce: true
    field :type, String.t(), enforce: true
    field :arguments, list() | boolean() | integer() | nil | number() | map() | String.t()
    field :seq, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"command", :command} => str(),
      {"type", :type} => oneof(["request"]),
      optional({"arguments", :arguments}) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
      {"seq", :seq} => int(),
    })
  end
end
