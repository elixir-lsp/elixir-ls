# codegen: do not edit
defmodule GenLSP.Enumerations.DiagnosticSeverity do
  @moduledoc """
  The diagnostic's severity.
  """

  @type t :: 1 | 2 | 3 | 4

  import SchematicV, warn: false

  @doc """
  Reports an error.
  """
  @spec error() :: 1
  def error, do: 1

  @doc """
  Reports a warning.
  """
  @spec warning() :: 2
  def warning, do: 2

  @doc """
  Reports an information.
  """
  @spec information() :: 3
  def information, do: 3

  @doc """
  Reports a hint.
  """
  @spec hint() :: 4
  def hint, do: 4

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      1,
      2,
      3,
      4
    ])
  end
end
