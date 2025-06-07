# codegen: do not edit
defmodule GenLSP.Enumerations.NotebookCellKind do
  @moduledoc """
  A notebook cell kind.

  @since 3.17.0
  """

  @type t :: 1 | 2

  import Schematic, warn: false

  @doc """
  A markup-cell is formatted source that is used for display.
  """
  @spec markup() :: 1
  def markup, do: 1

  @doc """
  A code-cell is source code.
  """
  @spec code() :: 2
  def code, do: 2

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      1,
      2
    ])
  end
end
