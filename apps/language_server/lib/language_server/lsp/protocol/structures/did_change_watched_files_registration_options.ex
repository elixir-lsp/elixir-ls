# codegen: do not edit
defmodule GenLSP.Structures.DidChangeWatchedFilesRegistrationOptions do
  @moduledoc """
  Describe options to be used when registered for text document change events.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * watchers: The watchers to register.
  """

  typedstruct do
    field(:watchers, list(GenLSP.Structures.FileSystemWatcher.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"watchers", :watchers} => list(GenLSP.Structures.FileSystemWatcher.schematic())
    })
  end
end
