# codegen: do not edit
defmodule GenLSP.Requests.WorkspaceSemanticTokensRefresh do
  @moduledoc """
  @since 3.16.0

  Message Direction: serverToClient
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "workspace/semanticTokens/refresh")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
  end

  @type result :: nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/semanticTokens/refresh",
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
