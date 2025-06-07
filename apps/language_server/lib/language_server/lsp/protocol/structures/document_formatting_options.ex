# codegen: do not edit
defmodule GenLSP.Structures.DocumentFormattingOptions do
  @moduledoc """
  Provider options for a {@link DocumentFormattingRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * work_done_progress
  """
  
  typedstruct do
    field :work_done_progress, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"workDoneProgress", :work_done_progress}) => bool()
    })
  end
end
