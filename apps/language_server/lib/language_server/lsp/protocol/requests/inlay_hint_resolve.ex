# codegen: do not edit
defmodule GenLSP.Requests.InlayHintResolve do
  @moduledoc """
  A request to resolve additional properties for an inlay hint.
  The request's parameter is of type {@link InlayHint}, the response is
  of type {@link InlayHint} or a Thenable that resolves to such.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "inlayHint/resolve")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.InlayHint.t())
  end

  @type result :: GenLSP.Structures.InlayHint.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "inlayHint/resolve",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.InlayHint.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      GenLSP.Structures.InlayHint.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
