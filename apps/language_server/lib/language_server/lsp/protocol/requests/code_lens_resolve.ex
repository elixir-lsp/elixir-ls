# codegen: do not edit
defmodule GenLSP.Requests.CodeLensResolve do
  @moduledoc """
  A request to resolve a command for a given code lens.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "codeLens/resolve")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.CodeLens.t())
  end

  @type result :: GenLSP.Structures.CodeLens.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "codeLens/resolve",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.CodeLens.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      GenLSP.Structures.CodeLens.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
