# codegen: do not edit
defmodule GenLSP.Structures.NotebookCellTextDocumentFilter do
  @moduledoc """
  A notebook cell text document filter denotes a cell text
  document by different properties.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * notebook: A filter that matches against the notebook
    containing the notebook cell. If a string
    value is provided it matches against the
    notebook type. '*' matches every notebook.
  * language: A language id like `python`.

    Will be matched against the language id of the
    notebook cell document. '*' matches every language.
  """

  typedstruct do
    field(:notebook, String.t() | GenLSP.TypeAlias.NotebookDocumentFilter.t(), enforce: true)
    field(:language, String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"notebook", :notebook} =>
        oneof([str(), GenLSP.TypeAlias.NotebookDocumentFilter.schematic()]),
      optional({"language", :language}) => str()
    })
  end
end
