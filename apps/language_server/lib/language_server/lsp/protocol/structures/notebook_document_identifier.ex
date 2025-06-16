# codegen: do not edit
defmodule GenLSP.Structures.NotebookDocumentIdentifier do
  @moduledoc """
  A literal to identify a notebook document in the client.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The notebook document's uri.
  """

  typedstruct do
    field(:uri, GenLSP.BaseTypes.uri(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str()
    })
  end
end
