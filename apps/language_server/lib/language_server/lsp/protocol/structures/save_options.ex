# codegen: do not edit
defmodule GenLSP.Structures.SaveOptions do
  @moduledoc """
  Save options.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * include_text: The client is supposed to include the content on save.
  """
  
  typedstruct do
    field :include_text, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"includeText", :include_text}) => bool()
    })
  end
end
