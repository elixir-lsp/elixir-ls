# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokensLegend do
  @moduledoc """
  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * token_types: The token types a server uses.
  * token_modifiers: The token modifiers a server uses.
  """

  typedstruct do
    field(:token_types, list(String.t()), enforce: true)
    field(:token_modifiers, list(String.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"tokenTypes", :token_types} => list(str()),
      {"tokenModifiers", :token_modifiers} => list(str())
    })
  end
end
