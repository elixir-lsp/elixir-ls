# codegen: do not edit
defmodule GenLSP.Enumerations.FileOperationPatternKind do
  @moduledoc """
  A pattern kind describing if a glob pattern matches a file a folder or
  both.

  @since 3.16.0
  """

  @type t :: String.t()

  import Schematic, warn: false

  @doc """
  The pattern matches a file only.
  """
  @spec file() :: String.t()
  def file, do: "file"

  @doc """
  The pattern matches a folder only.
  """
  @spec folder() :: String.t()
  def folder, do: "folder"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "file",
      "folder"
    ])
  end
end
