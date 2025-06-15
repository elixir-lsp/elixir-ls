# codegen: do not edit
defmodule GenLSP.Structures.ApplyWorkspaceEditParams do
  @moduledoc """
  The parameters passed via an apply workspace edit request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * label: An optional label of the workspace edit. This label is
    presented in the user interface for example on an undo
    stack to undo the workspace edit.
  * edit: The edits to apply.
  """

  typedstruct do
    field(:label, String.t())
    field(:edit, GenLSP.Structures.WorkspaceEdit.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"label", :label}) => str(),
      {"edit", :edit} => GenLSP.Structures.WorkspaceEdit.schematic()
    })
  end
end
