# codegen: do not edit
defmodule GenLSP.Structures.VersionedNotebookDocumentIdentifier do
  @moduledoc """
  A versioned notebook document identifier.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * version: The version number of this notebook document.
  * uri: The notebook document's uri.
  """

  typedstruct do
    field(:version, integer(), enforce: true)
    field(:uri, GenLSP.BaseTypes.uri(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"version", :version} => int(),
      {"uri", :uri} => str()
    })
  end
end
