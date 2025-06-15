# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceFolder do
  @moduledoc """
  A workspace folder inside a client.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The associated URI for this workspace folder.
  * name: The name of the workspace folder. Used to refer to this
    workspace folder in the user interface.
  """

  typedstruct do
    field(:uri, GenLSP.BaseTypes.uri(), enforce: true)
    field(:name, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str(),
      {"name", :name} => str()
    })
  end
end
