# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokensDelta do
  @moduledoc """
  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * result_id
  * edits: The semantic token edits to transform a previous result into a new result.
  """
  
  typedstruct do
    field :result_id, String.t()
    field :edits, list(GenLSP.Structures.SemanticTokensEdit.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"resultId", :result_id}) => str(),
      {"edits", :edits} => list(GenLSP.Structures.SemanticTokensEdit.schematic())
    })
  end
end
