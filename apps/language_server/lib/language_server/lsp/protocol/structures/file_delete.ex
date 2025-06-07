# codegen: do not edit
defmodule GenLSP.Structures.FileDelete do
  @moduledoc """
  Represents information on a file/folder delete.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: A file:// URI for the location of the file/folder being deleted.
  """
  
  typedstruct do
    field :uri, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str()
    })
  end
end
