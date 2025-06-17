# codegen: do not edit
defmodule GenLSP.Enumerations.TextDocumentSyncKind do
  @moduledoc """
  Defines how the host (editor) should sync
  document changes to the language server.
  """

  @type t :: 0 | 1 | 2

  import SchematicV, warn: false

  @doc """
  Documents should not be synced at all.
  """
  @spec none() :: 0
  def none, do: 0

  @doc """
  Documents are synced by always sending the full content
  of the document.
  """
  @spec full() :: 1
  def full, do: 1

  @doc """
  Documents are synced by sending the full content on open.
  After that only incremental updates to the document are
  send.
  """
  @spec incremental() :: 2
  def incremental, do: 2

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      0,
      1,
      2
    ])
  end
end
