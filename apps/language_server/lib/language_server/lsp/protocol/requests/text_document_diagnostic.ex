# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentDiagnostic do
  @moduledoc """
  The document diagnostic request definition.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "textDocument/diagnostic"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.DocumentDiagnosticParams.t()
  end

  @type result :: GenLSP.TypeAlias.DocumentDiagnosticReport.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/diagnostic",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.DocumentDiagnosticParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      GenLSP.TypeAlias.DocumentDiagnosticReport.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
