# codegen: do not edit
defmodule GenLSP.Enumerations.CodeActionTriggerKind do
  @moduledoc """
  The reason why code actions were requested.

  @since 3.17.0
  """

  @type t :: 1 | 2

  import SchematicV, warn: false

  @doc """
  Code actions were explicitly requested by the user or by an extension.
  """
  @spec invoked() :: 1
  def invoked, do: 1

  @doc """
  Code actions were requested automatically.

  This typically happens when current selection in a file changes, but can
  also be triggered when file content changes.
  """
  @spec automatic() :: 2
  def automatic, do: 2

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      1,
      2
    ])
  end
end
