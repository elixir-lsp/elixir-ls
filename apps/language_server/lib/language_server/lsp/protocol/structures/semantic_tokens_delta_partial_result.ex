# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokensDeltaPartialResult do
  @moduledoc """
  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * edits
  """

  typedstruct do
    field(:edits, list(GenLSP.Structures.SemanticTokensEdit.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"edits", :edits} => list(GenLSP.Structures.SemanticTokensEdit.schematic())
    })
  end
end
