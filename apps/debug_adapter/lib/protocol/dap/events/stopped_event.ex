# codegen: do not edit

defmodule GenDAP.Events.StoppedEvent do
  @moduledoc """
  The event indicates that the execution of the debuggee has stopped due to some condition.
  This can be caused by a breakpoint previously set, a stepping request has completed, by executing a debugger statement etc.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "stopped"
    field :body, %{reason: String.t(), description: String.t(), text: String.t(), thread_id: integer(), preserve_focus_hint: boolean(), all_threads_stopped: boolean(), hit_breakpoint_ids: list(integer())}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "stopped",
      :body => map(%{
        :reason => oneof(["step", "breakpoint", "exception", "pause", "entry", "goto", "function breakpoint", "data breakpoint", "instruction breakpoint"]),
        optional(:description) => str(),
        optional(:text) => str(),
        optional({:threadId, :thread_id}) => int(),
        optional({:preserveFocusHint, :preserve_focus_hint}) => bool(),
        optional({:allThreadsStopped, :all_threads_stopped}) => bool(),
        optional({:hitBreakpointIds, :hit_breakpoint_ids}) => list(int())
      })
    })
  end
end
