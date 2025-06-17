# codegen: do not edit
defmodule GenLSP.Structures.TextDocumentIdentifier do
  @moduledoc """
  A literal to identify a text document in the client.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The text document's uri.
  """

  typedstruct do
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str()
    })
  end
end
