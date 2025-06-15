# codegen: do not edit
defmodule GenLSP.Requests.WorkspaceDiagnosticRefresh do
  @moduledoc """
  The diagnostic refresh request definition.

  @since 3.17.0

  Message Direction: serverToClient
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "workspace/diagnostic/refresh")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
  end

  @type result :: nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/diagnostic/refresh",
      jsonrpc: "2.0",
      id: int()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      nil,
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
