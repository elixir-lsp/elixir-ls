# codegen: do not edit

defmodule GenDAP.Events.ModuleEvent do
  @moduledoc """
  The event indicates that some information about a module has changed.

  Message Direction: adapter -> client
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * body: Event-specific information.
  * event: Type of event.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """

  typedstruct do
    @typedoc "A type defining DAP event module"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "module")

    field(
      :body,
      %{required(:module) => GenDAP.Structures.Module.t(), required(:reason) => String.t()},
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "module",
      :body =>
        map(%{
          {"module", :module} => GenDAP.Structures.Module.schematic(),
          {"reason", :reason} => oneof(["new", "changed", "removed"])
        })
    })
  end
end
