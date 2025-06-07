# codegen: do not edit
defmodule GenLSP.Requests.WorkspaceDiagnostic do
  @moduledoc """
  The workspace diagnostic request definition.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "workspace/diagnostic"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.WorkspaceDiagnosticParams.t()
  end

  @type result :: GenLSP.Structures.WorkspaceDiagnosticReport.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "workspace/diagnostic",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.WorkspaceDiagnosticParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      GenLSP.Structures.WorkspaceDiagnosticReport.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
