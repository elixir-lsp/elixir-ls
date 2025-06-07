# codegen: do not edit
defmodule GenLSP.Notifications.TelemetryEvent do
  @moduledoc """
  The telemetry event notification is sent from the server to the client to ask
  the client to log telemetry data.

  Message Direction: serverToClient
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "telemetry/event"
    field :jsonrpc, String.t(), default: "2.0"
    field :params, GenLSP.TypeAlias.LSPAny.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "telemetry/event",
      jsonrpc: "2.0",
      params: GenLSP.TypeAlias.LSPAny.schematic()
    })
  end
end
