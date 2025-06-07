# codegen: do not edit
defmodule GenLSP.Enumerations.PositionEncodingKind do
  @moduledoc """
  A set of predefined position encoding kinds.

  @since 3.17.0
  """

  @type t :: String.t()

  import Schematic, warn: false

  @doc """
  Character offsets count UTF-8 code units.
  """
  @spec utf8() :: String.t()
  def utf8, do: "utf-8"

  @doc """
  Character offsets count UTF-16 code units.

  This is the default and must always be supported
  by servers
  """
  @spec utf16() :: String.t()
  def utf16, do: "utf-16"

  @doc """
  Character offsets count UTF-32 code units.

  Implementation note: these are the same as Unicode code points,
  so this `PositionEncodingKind` may also be used for an
  encoding-agnostic representation of character offsets.
  """
  @spec utf32() :: String.t()
  def utf32, do: "utf-32"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "utf-8",
      "utf-16",
      "utf-32",
      str()
    ])
  end
end
