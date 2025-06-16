# codegen: do not edit
defmodule GenLSP.Structures.FileEvent do
  @moduledoc """
  An event describing a file change.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The file's uri.
  * type: The change type.
  """

  typedstruct do
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
    field(:type, GenLSP.Enumerations.FileChangeType.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str(),
      {"type", :type} => GenLSP.Enumerations.FileChangeType.schematic()
    })
  end
end
