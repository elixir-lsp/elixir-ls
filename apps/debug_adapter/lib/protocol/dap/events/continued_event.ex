# codegen: do not edit

defmodule GenDAP.Events.ContinuedEvent do
  @moduledoc """
  The event indicates that the execution of the debuggee has continued.
  Please note: a debug adapter is not expected to send this event in response to a request that implies that execution continues, e.g. `launch` or `continue`.
  It is only necessary to send a `continued` event if there was no previous request that implied this.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "continued"
    field :body, %{thread_id: integer(), all_threads_continued: boolean()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "continued",
      :body => map(%{
        {:threadId, :thread_id} => int(),
        optional({:allThreadsContinued, :all_threads_continued}) => bool()
      })
    })
  end
end
