# codegen: do not edit
defmodule GenLSP.Enumerations.DocumentHighlightKind do
  @moduledoc """
  A document highlight kind.
  """

  @type t :: 1 | 2 | 3

  import Schematic, warn: false

  @doc """
  A textual occurrence.
  """
  @spec text() :: 1
  def text, do: 1

  @doc """
  Read-access of a symbol, like reading a variable.
  """
  @spec read() :: 2
  def read, do: 2

  @doc """
  Write-access of a symbol, like writing to a variable.
  """
  @spec write() :: 3
  def write, do: 3

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      1,
      2,
      3
    ])
  end
end
