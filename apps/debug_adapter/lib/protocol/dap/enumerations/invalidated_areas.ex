# codegen: do not edit
defmodule GenDAP.Enumerations.InvalidatedAreas do
  @moduledoc """
  Logical areas that can be invalidated by the `invalidated` event.
  """

  @typedoc "A type defining DAP enumeration InvalidatedAreas"
  @type t :: String.t()

  import Schematic, warn: false

  @doc """
  All previously fetched data has become invalid and needs to be refetched.
  """
  @spec all() :: String.t()
  def all, do: "all"

  @doc """
  Previously fetched stack related data has become invalid and needs to be refetched.
  """
  @spec stacks() :: String.t()
  def stacks, do: "stacks"

  @doc """
  Previously fetched thread related data has become invalid and needs to be refetched.
  """
  @spec threads() :: String.t()
  def threads, do: "threads"

  @doc """
  Previously fetched variable data has become invalid and needs to be refetched.
  """
  @spec variables() :: String.t()
  def variables, do: "variables"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "all",
      "stacks",
      "threads",
      "variables",
      str()
    ])
  end
end
