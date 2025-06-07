# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceFoldersChangeEvent do
  @moduledoc """
  The workspace folder change event.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * added: The array of added workspace folders
  * removed: The array of the removed workspace folders
  """
  
  typedstruct do
    field :added, list(GenLSP.Structures.WorkspaceFolder.t()), enforce: true
    field :removed, list(GenLSP.Structures.WorkspaceFolder.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"added", :added} => list(GenLSP.Structures.WorkspaceFolder.schematic()),
      {"removed", :removed} => list(GenLSP.Structures.WorkspaceFolder.schematic())
    })
  end
end
