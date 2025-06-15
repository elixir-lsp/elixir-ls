# codegen: do not edit
defmodule GenLSP.Structures.UnchangedDocumentDiagnosticReport do
  @moduledoc """
  A diagnostic report indicating that the last returned
  report is still accurate.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * kind: A document diagnostic report indicating
    no changes to the last result. A server can
    only return `unchanged` if result ids are
    provided.
  * result_id: A result id which will be sent on the next
    diagnostic request for the same document.
  """

  typedstruct do
    field(:kind, String.t(), enforce: true)
    field(:result_id, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"kind", :kind} => "unchanged",
      {"resultId", :result_id} => str()
    })
  end
end
