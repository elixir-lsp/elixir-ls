# codegen: do not edit
defmodule GenLSP.Structures.TextDocumentItem do
  @moduledoc """
  An item to transfer a text document from the client to the
  server.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The text document's uri.
  * language_id: The text document's language identifier.
  * version: The version number of this document (it will increase after each
    change, including undo/redo).
  * text: The content of the opened text document.
  """

  typedstruct do
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
    field(:language_id, String.t(), enforce: true)
    field(:version, integer(), enforce: true)
    field(:text, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str(),
      {"languageId", :language_id} => str(),
      {"version", :version} => int(),
      {"text", :text} => str()
    })
  end
end
