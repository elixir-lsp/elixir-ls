# codegen: do not edit
defmodule GenLSP.Structures.RelatedFullDocumentDiagnosticReport do
  @moduledoc """
  A full diagnostic report with a set of related documents.

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
  * kind: A full document diagnostic report.
  * result_id: An optional result id. If provided it will
    be sent on the next diagnostic request for the
    same document.
  * items: The actual items.
  """

  typedstruct do
    field(:related_documents, %{
      GenLSP.BaseTypes.document_uri() =>
        GenLSP.Structures.FullDocumentDiagnosticReport.t()
        | GenLSP.Structures.UnchangedDocumentDiagnosticReport.t()
    })

    field(:kind, String.t(), enforce: true)
    field(:result_id, String.t())
    field(:items, list(GenLSP.Structures.Diagnostic.t()), enforce: true)
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
      {"kind", :kind} => "full",
      optional({"resultId", :result_id}) => str(),
      {"items", :items} => list(GenLSP.Structures.Diagnostic.schematic())
    })
  end
end
