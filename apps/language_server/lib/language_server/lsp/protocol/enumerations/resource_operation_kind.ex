# codegen: do not edit
defmodule GenLSP.Enumerations.ResourceOperationKind do
  @type t :: String.t()

  import SchematicV, warn: false

  @doc """
  Supports creating new files and folders.
  """
  @spec create() :: String.t()
  def create, do: "create"

  @doc """
  Supports renaming existing files and folders.
  """
  @spec rename() :: String.t()
  def rename, do: "rename"

  @doc """
  Supports deleting existing files and folders.
  """
  @spec delete() :: String.t()
  def delete, do: "delete"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "create",
      "rename",
      "delete"
    ])
  end
end
