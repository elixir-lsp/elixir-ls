# codegen: do not edit

defmodule GenDAP.Events.ProcessEvent do
  @moduledoc """
  The event indicates that the debugger has begun debugging a new process. Either one that it has launched, or one that it has attached to.

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

  typedstruct do
    @typedoc "A type defining DAP event process"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "process")

    field(
      :body,
      %{
        required(:name) => String.t(),
        optional(:system_process_id) => integer(),
        optional(:is_local_process) => boolean(),
        optional(:start_method) => String.t(),
        optional(:pointer_size) => integer()
      },
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "process",
      :body =>
        map(%{
          {"name", :name} => str(),
          optional({"systemProcessId", :system_process_id}) => int(),
          optional({"isLocalProcess", :is_local_process}) => bool(),
          optional({"startMethod", :start_method}) =>
            oneof(["launch", "attach", "attachForSuspendedLaunch"]),
          optional({"pointerSize", :pointer_size}) => int()
        })
    })
  end
end
