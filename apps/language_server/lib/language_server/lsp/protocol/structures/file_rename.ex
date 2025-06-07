# codegen: do not edit
defmodule GenLSP.Structures.FileRename do
  @moduledoc """
  Represents information on a file/folder rename.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * old_uri: A file:// URI for the original location of the file/folder being renamed.
  * new_uri: A file:// URI for the new location of the file/folder being renamed.
  """
  
  typedstruct do
    field :old_uri, String.t(), enforce: true
    field :new_uri, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"oldUri", :old_uri} => str(),
      {"newUri", :new_uri} => str()
    })
  end
end
