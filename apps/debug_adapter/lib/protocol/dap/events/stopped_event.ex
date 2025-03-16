# codegen: do not edit

defmodule GenDAP.Events.StoppedEvent do
  @moduledoc """
  The event indicates that the execution of the debuggee has stopped due to some condition.
  This can be caused by a breakpoint previously set, a stepping request has completed, by executing a debugger statement etc.

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
    @typedoc "A type defining DAP event stopped"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "stopped")

    field(
      :body,
      %{
        required(:reason) => String.t(),
        optional(:description) => String.t(),
        optional(:text) => String.t(),
        optional(:thread_id) => integer(),
        optional(:preserve_focus_hint) => boolean(),
        optional(:all_threads_stopped) => boolean(),
        optional(:hit_breakpoint_ids) => list(integer())
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
      :event => "stopped",
      :body =>
        map(%{
          {"reason", :reason} =>
            oneof([
              "step",
              "breakpoint",
              "exception",
              "pause",
              "entry",
              "goto",
              "function breakpoint",
              "data breakpoint",
              "instruction breakpoint",
              str()
            ]),
          optional({"description", :description}) => str(),
          optional({"text", :text}) => str(),
          optional({"threadId", :thread_id}) => int(),
          optional({"preserveFocusHint", :preserve_focus_hint}) => bool(),
          optional({"allThreadsStopped", :all_threads_stopped}) => bool(),
          optional({"hitBreakpointIds", :hit_breakpoint_ids}) => list(int())
        })
    })
  end
end
