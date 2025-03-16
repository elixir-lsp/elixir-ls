# codegen: do not edit
defmodule GenDAP.Enumerations.ChecksumAlgorithm do
  @moduledoc """
  Names of checksum algorithms that may be supported by a debug adapter.
  """

  @typedoc "A type defining DAP enumeration ChecksumAlgorithm"
  @type t :: String.t()

  import Schematic, warn: false

  @spec md5() :: String.t()
  def md5, do: "MD5"

  @spec sha1() :: String.t()
  def sha1, do: "SHA1"

  @spec sha256() :: String.t()
  def sha256, do: "SHA256"

  @spec timestamp() :: String.t()
  def timestamp, do: "timestamp"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "MD5",
      "SHA1",
      "SHA256",
      "timestamp"
    ])
  end
end
