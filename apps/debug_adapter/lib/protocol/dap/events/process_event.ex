# codegen: do not edit

defmodule GenDAP.Events.ProcessEvent do
  @moduledoc """
  The event indicates that the debugger has begun debugging a new process. Either one that it has launched, or one that it has attached to.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "process"
    field :body, %{name: String.t(), system_process_id: integer(), is_local_process: boolean(), start_method: String.t(), pointer_size: integer()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "process",
      :body => map(%{
        :name => str(),
        optional({:systemProcessId, :system_process_id}) => int(),
        optional({:isLocalProcess, :is_local_process}) => bool(),
        optional({:startMethod, :start_method}) => oneof(["launch", "attach", "attachForSuspendedLaunch"]),
        optional({:pointerSize, :pointer_size}) => int()
      })
    })
  end
end
