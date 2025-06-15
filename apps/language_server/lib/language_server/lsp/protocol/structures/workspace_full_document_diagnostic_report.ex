# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceFullDocumentDiagnosticReport do
  @moduledoc """
  A full document diagnostic report for a workspace diagnostic result.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The URI for which diagnostic information is reported.
  * version: The version number for which the diagnostics are reported.
    If the document is not marked as open `null` can be provided.
  * kind: A full document diagnostic report.
  * result_id: An optional result id. If provided it will
    be sent on the next diagnostic request for the
    same document.
  * items: The actual items.
  """

  typedstruct do
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
    field(:version, integer() | nil, enforce: true)
    field(:kind, String.t(), enforce: true)
    field(:result_id, String.t())
    field(:items, list(GenLSP.Structures.Diagnostic.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str(),
      {"version", :version} => oneof([int(), nil]),
      {"kind", :kind} => "full",
      optional({"resultId", :result_id}) => str(),
      {"items", :items} => list(GenLSP.Structures.Diagnostic.schematic())
    })
  end
end
