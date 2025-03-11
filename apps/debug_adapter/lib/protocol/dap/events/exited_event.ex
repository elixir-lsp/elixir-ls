# codegen: do not edit

defmodule GenDAP.Events.ExitedEvent do
  @moduledoc """
  The event indicates that the debuggee has exited and returns its exit code.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "exited"
    field :body, %{exit_code: integer()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "exited",
      :body => map(%{
        {:exitCode, :exit_code} => int()
      })
    })
  end
end
