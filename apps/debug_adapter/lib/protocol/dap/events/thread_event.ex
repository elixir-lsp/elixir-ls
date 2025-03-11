# codegen: do not edit

defmodule GenDAP.Events.ThreadEvent do
  @moduledoc """
  The event indicates that a thread has started or exited.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "thread"
    field :body, %{reason: String.t(), thread_id: integer()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "thread",
      :body => map(%{
        :reason => oneof(["started", "exited"]),
        {:threadId, :thread_id} => int()
      })
    })
  end
end
