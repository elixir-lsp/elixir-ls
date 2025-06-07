# codegen: do not edit
defmodule GenLSP.Enumerations.MonikerKind do
  @moduledoc """
  The moniker kind.

  @since 3.16.0
  """

  @type t :: String.t()

  import Schematic, warn: false

  @doc """
  The moniker represent a symbol that is imported into a project
  """
  @spec import() :: String.t()
  def import, do: "import"

  @doc """
  The moniker represents a symbol that is exported from a project
  """
  @spec export() :: String.t()
  def export, do: "export"

  @doc """
  The moniker represents a symbol that is local to a project (e.g. a local
  variable of a function, a class not visible outside the project, ...)
  """
  @spec local() :: String.t()
  def local, do: "local"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "import",
      "export",
      "local"
    ])
  end
end
