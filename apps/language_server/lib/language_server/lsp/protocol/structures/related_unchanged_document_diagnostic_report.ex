# codegen: do not edit
defmodule GenLSP.Structures.RelatedUnchangedDocumentDiagnosticReport do
  @moduledoc """
  An unchanged diagnostic report with a set of related documents.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * related_documents: Diagnostics of related documents. This information is useful
    in programming languages where code in a file A can generate
    diagnostics in a file B which A depends on. An example of
    such a language is C/C++ where marco definitions in a file
    a.cpp and result in errors in a header file b.hpp.

    @since 3.17.0
  * kind: A document diagnostic report indicating
    no changes to the last result. A server can
    only return `unchanged` if result ids are
    provided.
  * result_id: A result id which will be sent on the next
    diagnostic request for the same document.
  """
  
  typedstruct do
    field :related_documents, %{
      GenLSP.BaseTypes.document_uri() =>
        GenLSP.Structures.FullDocumentDiagnosticReport.t()
        | GenLSP.Structures.UnchangedDocumentDiagnosticReport.t()
    }

    field :kind, String.t(), enforce: true
    field :result_id, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"relatedDocuments", :related_documents}) =>
        map(
          keys: str(),
          values:
            oneof([
              GenLSP.Structures.FullDocumentDiagnosticReport.schematic(),
              GenLSP.Structures.UnchangedDocumentDiagnosticReport.schematic()
            ])
        ),
      {"kind", :kind} => "unchanged",
      {"resultId", :result_id} => str()
    })
  end
end
