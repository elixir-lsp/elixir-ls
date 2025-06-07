# codegen: do not edit
defmodule GenLSP.Enumerations.MessageType do
  @moduledoc """
  The message type
  """

  @type t :: 1 | 2 | 3 | 4

  import Schematic, warn: false

  @doc """
  An error message.
  """
  @spec error() :: 1
  def error, do: 1

  @doc """
  A warning message.
  """
  @spec warning() :: 2
  def warning, do: 2

  @doc """
  An information message.
  """
  @spec info() :: 3
  def info, do: 3

  @doc """
  A log message.
  """
  @spec log() :: 4
  def log, do: 4

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      1,
      2,
      3,
      4
    ])
  end
end
