# codegen: do not edit
defmodule GenLSP.Structures.NotebookCell do
  @moduledoc """
  A notebook cell.

  A cell's document URI must be unique across ALL notebook
  cells and can therefore be used to uniquely identify a
  notebook cell or the cell's text document.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * kind: The cell's kind
  * document: The URI of the cell's text document
    content.
  * metadata: Additional metadata stored with the cell.

    Note: should always be an object literal (e.g. LSPObject)
  * execution_summary: Additional execution summary information
    if supported by the client.
  """

  typedstruct do
    field(:kind, GenLSP.Enumerations.NotebookCellKind.t(), enforce: true)
    field(:document, GenLSP.BaseTypes.document_uri(), enforce: true)
    field(:metadata, GenLSP.TypeAlias.LSPObject.t())
    field(:execution_summary, GenLSP.Structures.ExecutionSummary.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"kind", :kind} => GenLSP.Enumerations.NotebookCellKind.schematic(),
      {"document", :document} => str(),
      optional({"metadata", :metadata}) => GenLSP.TypeAlias.LSPObject.schematic(),
      optional({"executionSummary", :execution_summary}) =>
        GenLSP.Structures.ExecutionSummary.schematic()
    })
  end
end
