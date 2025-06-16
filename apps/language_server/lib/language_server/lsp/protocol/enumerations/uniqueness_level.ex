# codegen: do not edit
defmodule GenLSP.Enumerations.UniquenessLevel do
  @moduledoc """
  Moniker uniqueness level to define scope of the moniker.

  @since 3.16.0
  """

  @type t :: String.t()

  import SchematicV, warn: false

  @doc """
  The moniker is only unique inside a document
  """
  @spec document() :: String.t()
  def document, do: "document"

  @doc """
  The moniker is unique inside a project for which a dump got created
  """
  @spec project() :: String.t()
  def project, do: "project"

  @doc """
  The moniker is unique inside the group to which a project belongs
  """
  @spec group() :: String.t()
  def group, do: "group"

  @doc """
  The moniker is unique inside the moniker scheme.
  """
  @spec scheme() :: String.t()
  def scheme, do: "scheme"

  @doc """
  The moniker is globally unique
  """
  @spec global() :: String.t()
  def global, do: "global"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "document",
      "project",
      "group",
      "scheme",
      "global"
    ])
  end
end
