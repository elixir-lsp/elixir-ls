# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentInlineValue do
  @moduledoc """
  A request to provide inline values in a document. The request's parameter is of
  type {@link InlineValueParams}, the response is of type
  {@link InlineValue InlineValue[]} or a Thenable that resolves to such.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "textDocument/inlineValue"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.InlineValueParams.t()
  end

  @type result :: list(GenLSP.TypeAlias.InlineValue.t()) | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/inlineValue",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.InlineValueParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([list(GenLSP.TypeAlias.InlineValue.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
