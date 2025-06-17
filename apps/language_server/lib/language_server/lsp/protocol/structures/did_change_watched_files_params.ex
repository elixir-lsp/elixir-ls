# codegen: do not edit
defmodule GenLSP.Structures.DidChangeWatchedFilesParams do
  @moduledoc """
  The watched files change notification's parameters.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * changes: The actual file events.
  """

  typedstruct do
    field(:changes, list(GenLSP.Structures.FileEvent.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"changes", :changes} => list(GenLSP.Structures.FileEvent.schematic())
    })
  end
end
