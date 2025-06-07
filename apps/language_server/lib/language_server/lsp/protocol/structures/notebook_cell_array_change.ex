# codegen: do not edit
defmodule GenLSP.Structures.NotebookCellArrayChange do
  @moduledoc """
  A change describing how to move a `NotebookCell`
  array from state S to S'.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * start: The start oftest of the cell that changed.
  * delete_count: The deleted cells
  * cells: The new cells, if any
  """
  
  typedstruct do
    field :start, GenLSP.BaseTypes.uinteger(), enforce: true
    field :delete_count, GenLSP.BaseTypes.uinteger(), enforce: true
    field :cells, list(GenLSP.Structures.NotebookCell.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"start", :start} => int(),
      {"deleteCount", :delete_count} => int(),
      optional({"cells", :cells}) => list(GenLSP.Structures.NotebookCell.schematic())
    })
  end
end
