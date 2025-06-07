# codegen: do not edit
defmodule GenLSP.Structures.FullDocumentDiagnosticReport do
  @moduledoc """
  A diagnostic report with a full set of problems.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * kind: A full document diagnostic report.
  * result_id: An optional result id. If provided it will
    be sent on the next diagnostic request for the
    same document.
  * items: The actual items.
  """
  
  typedstruct do
    field :kind, String.t(), enforce: true
    field :result_id, String.t()
    field :items, list(GenLSP.Structures.Diagnostic.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"kind", :kind} => "full",
      optional({"resultId", :result_id}) => str(),
      {"items", :items} => list(GenLSP.Structures.Diagnostic.schematic())
    })
  end
end
