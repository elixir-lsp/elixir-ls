# codegen: do not edit
defmodule GenLSP.Structures.OptionalVersionedTextDocumentIdentifier do
  @moduledoc """
  A text document identifier to optionally denote a specific version of a text document.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * version: The version number of this document. If a versioned text document identifier
    is sent from the server to the client and the file is not open in the editor
    (the server has not received an open notification before) the server can send
    `null` to indicate that the version is unknown and the content on disk is the
    truth (as specified with document content ownership).
  * uri: The text document's uri.
  """

  typedstruct do
    field(:version, integer() | nil, enforce: true)
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"version", :version} => oneof([int(), nil]),
      {"uri", :uri} => str()
    })
  end
end
