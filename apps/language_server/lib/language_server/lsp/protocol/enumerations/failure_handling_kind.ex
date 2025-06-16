# codegen: do not edit
defmodule GenLSP.Enumerations.FailureHandlingKind do
  @type t :: String.t()

  import SchematicV, warn: false

  @doc """
  Applying the workspace change is simply aborted if one of the changes provided
  fails. All operations executed before the failing operation stay executed.
  """
  @spec abort() :: String.t()
  def abort, do: "abort"

  @doc """
  All operations are executed transactional. That means they either all
  succeed or no changes at all are applied to the workspace.
  """
  @spec transactional() :: String.t()
  def transactional, do: "transactional"

  @doc """
  If the workspace edit contains only textual file changes they are executed transactional.
  If resource changes (create, rename or delete file) are part of the change the failure
  handling strategy is abort.
  """
  @spec text_only_transactional() :: String.t()
  def text_only_transactional, do: "textOnlyTransactional"

  @doc """
  The client tries to undo the operations already executed. But there is no
  guarantee that this is succeeding.
  """
  @spec undo() :: String.t()
  def undo, do: "undo"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "abort",
      "transactional",
      "textOnlyTransactional",
      "undo"
    ])
  end
end
