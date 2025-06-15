# codegen: do not edit
defmodule GenLSP.Notifications.WindowShowMessage do
  @moduledoc """
  The show message notification is sent from a server to a client to ask
  the client to display a particular message in the user interface.

  Message Direction: serverToClient
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "window/showMessage")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.ShowMessageParams.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "window/showMessage",
      jsonrpc: "2.0",
      params: GenLSP.Structures.ShowMessageParams.schematic()
    })
  end
end
