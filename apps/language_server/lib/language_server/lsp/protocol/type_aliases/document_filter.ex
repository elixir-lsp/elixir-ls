# codegen: do not edit
defmodule GenLSP.TypeAlias.DocumentFilter do
  @moduledoc """
  A document filter describes a top level text document or
  a notebook cell document.

  @since 3.17.0 - proposed support for NotebookCellTextDocumentFilter.
  """

  import SchematicV, warn: false

  @type t ::
          GenLSP.TypeAlias.TextDocumentFilter.t()
          | GenLSP.Structures.NotebookCellTextDocumentFilter.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      GenLSP.TypeAlias.TextDocumentFilter.schematic(),
      GenLSP.Structures.NotebookCellTextDocumentFilter.schematic()
    ])
  end
end
