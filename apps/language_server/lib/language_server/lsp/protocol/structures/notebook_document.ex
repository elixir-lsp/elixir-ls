# codegen: do not edit
defmodule GenLSP.Structures.NotebookDocument do
  @moduledoc """
  A notebook document.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The notebook document's uri.
  * notebook_type: The type of the notebook.
  * version: The version number of this document (it will increase after each
    change, including undo/redo).
  * metadata: Additional metadata stored with the notebook
    document.

    Note: should always be an object literal (e.g. LSPObject)
  * cells: The cells of a notebook.
  """
  
  typedstruct do
    field :uri, GenLSP.BaseTypes.uri(), enforce: true
    field :notebook_type, String.t(), enforce: true
    field :version, integer(), enforce: true
    field :metadata, GenLSP.TypeAlias.LSPObject.t()
    field :cells, list(GenLSP.Structures.NotebookCell.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str(),
      {"notebookType", :notebook_type} => str(),
      {"version", :version} => int(),
      optional({"metadata", :metadata}) => GenLSP.TypeAlias.LSPObject.schematic(),
      {"cells", :cells} => list(GenLSP.Structures.NotebookCell.schematic())
    })
  end
end
