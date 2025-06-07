# codegen: do not edit
defmodule GenLSP.TypeAlias.WorkspaceDocumentDiagnosticReport do
  @moduledoc """
  A workspace diagnostic document report.

  @since 3.17.0
  """

  import Schematic, warn: false

  @type t ::
          GenLSP.Structures.WorkspaceFullDocumentDiagnosticReport.t()
          | GenLSP.Structures.WorkspaceUnchangedDocumentDiagnosticReport.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      GenLSP.Structures.WorkspaceFullDocumentDiagnosticReport.schematic(),
      GenLSP.Structures.WorkspaceUnchangedDocumentDiagnosticReport.schematic()
    ])
  end
end
