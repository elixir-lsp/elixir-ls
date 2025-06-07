# codegen: do not edit
defmodule GenLSP.Structures.DeleteFilesParams do
  @moduledoc """
  The parameters sent in notifications/requests for user-initiated deletes of
  files.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * files: An array of all files/folders deleted in this operation.
  """
  
  typedstruct do
    field :files, list(GenLSP.Structures.FileDelete.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"files", :files} => list(GenLSP.Structures.FileDelete.schematic())
    })
  end
end
