# codegen: do not edit
defmodule GenDAP.Structures.DisconnectArguments do
  @moduledoc """
  Arguments for `disconnect` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * restart: A value of true indicates that this `disconnect` request is part of a restart sequence.
  * suspend_debuggee: Indicates whether the debuggee should stay suspended when the debugger is disconnected.
    If unspecified, the debuggee should resume execution.
    The attribute is only honored by a debug adapter if the corresponding capability `supportSuspendDebuggee` is true.
  * terminate_debuggee: Indicates whether the debuggee should be terminated when the debugger is disconnected.
    If unspecified, the debug adapter is free to do whatever it thinks is best.
    The attribute is only honored by a debug adapter if the corresponding capability `supportTerminateDebuggee` is true.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure DisconnectArguments"
    field :restart, boolean()
    field :suspend_debuggee, boolean()
    field :terminate_debuggee, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"restart", :restart}) => bool(),
      optional({"suspendDebuggee", :suspend_debuggee}) => bool(),
      optional({"terminateDebuggee", :terminate_debuggee}) => bool(),
    })
  end
end
