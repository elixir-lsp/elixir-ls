# codegen: do not edit
defmodule GenLSP.Requests.DocumentLinkResolve do
  @moduledoc """
  Request to resolve additional information for a given document link. The request's
  parameter is of type {@link DocumentLink} the response
  is of type {@link DocumentLink} or a Thenable that resolves to such.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "documentLink/resolve")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.DocumentLink.t())
  end

  @type result :: GenLSP.Structures.DocumentLink.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "documentLink/resolve",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.DocumentLink.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      GenLSP.Structures.DocumentLink.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
