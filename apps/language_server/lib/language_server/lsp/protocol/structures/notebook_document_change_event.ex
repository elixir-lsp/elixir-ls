# codegen: do not edit
defmodule GenLSP.Structures.NotebookDocumentChangeEvent do
  @moduledoc """
  A change event for a notebook document.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * metadata: The changed meta data if any.

    Note: should always be an object literal (e.g. LSPObject)
  * cells: Changes to cells
  """

  typedstruct do
    field(:metadata, GenLSP.TypeAlias.LSPObject.t())
    field(:cells, map())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"metadata", :metadata}) => GenLSP.TypeAlias.LSPObject.schematic(),
      optional({"cells", :cells}) =>
        map(%{
          optional({"structure", :structure}) =>
            map(%{
              {"array", :array} => GenLSP.Structures.NotebookCellArrayChange.schematic(),
              optional({"didOpen", :did_open}) =>
                list(GenLSP.Structures.TextDocumentItem.schematic()),
              optional({"didClose", :did_close}) =>
                list(GenLSP.Structures.TextDocumentIdentifier.schematic())
            }),
          optional({"data", :data}) => list(GenLSP.Structures.NotebookCell.schematic()),
          optional({"textContent", :text_content}) =>
            list(
              map(%{
                {"document", :document} =>
                  GenLSP.Structures.VersionedTextDocumentIdentifier.schematic(),
                {"changes", :changes} =>
                  list(GenLSP.TypeAlias.TextDocumentContentChangeEvent.schematic())
              })
            )
        })
    })
  end
end
