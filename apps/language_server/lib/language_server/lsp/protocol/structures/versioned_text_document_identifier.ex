# codegen: do not edit
defmodule GenLSP.Structures.VersionedTextDocumentIdentifier do
  @moduledoc """
  A text document identifier to denote a specific version of a text document.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * version: The version number of this document.
  * uri: The text document's uri.
  """

  typedstruct do
    field(:version, integer(), enforce: true)
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"version", :version} => int(),
      {"uri", :uri} => str()
    })
  end
end
