# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceUnchangedDocumentDiagnosticReport do
  @moduledoc """
  An unchanged document diagnostic report for a workspace diagnostic result.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The URI for which diagnostic information is reported.
  * version: The version number for which the diagnostics are reported.
    If the document is not marked as open `null` can be provided.
  * kind: A document diagnostic report indicating
    no changes to the last result. A server can
    only return `unchanged` if result ids are
    provided.
  * result_id: A result id which will be sent on the next
    diagnostic request for the same document.
  """
  
  typedstruct do
    field :uri, GenLSP.BaseTypes.document_uri(), enforce: true
    field :version, integer() | nil, enforce: true
    field :kind, String.t(), enforce: true
    field :result_id, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str(),
      {"version", :version} => oneof([int(), nil]),
      {"kind", :kind} => "unchanged",
      {"resultId", :result_id} => str()
    })
  end
end
