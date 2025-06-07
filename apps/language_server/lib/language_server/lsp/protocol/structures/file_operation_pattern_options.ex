# codegen: do not edit
defmodule GenLSP.Structures.FileOperationPatternOptions do
  @moduledoc """
  Matching options for the file operation pattern.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * ignore_case: The pattern should be matched ignoring casing.
  """
  
  typedstruct do
    field :ignore_case, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"ignoreCase", :ignore_case}) => bool()
    })
  end
end
