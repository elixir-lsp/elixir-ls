# codegen: do not edit
defmodule GenLSP.Enumerations.SignatureHelpTriggerKind do
  @moduledoc """
  How a signature help was triggered.

  @since 3.15.0
  """

  @type t :: 1 | 2 | 3

  import Schematic, warn: false

  @doc """
  Signature help was invoked manually by the user or by a command.
  """
  @spec invoked() :: 1
  def invoked, do: 1

  @doc """
  Signature help was triggered by a trigger character.
  """
  @spec trigger_character() :: 2
  def trigger_character, do: 2

  @doc """
  Signature help was triggered by the cursor moving or by the document content changing.
  """
  @spec content_change() :: 3
  def content_change, do: 3

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
