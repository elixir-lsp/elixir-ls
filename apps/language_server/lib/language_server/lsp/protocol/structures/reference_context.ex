# codegen: do not edit
defmodule GenLSP.Structures.ReferenceContext do
  @moduledoc """
  Value-object that contains additional information when
  requesting references.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * include_declaration: Include the declaration of the current symbol.
  """

  typedstruct do
    field(:include_declaration, boolean(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"includeDeclaration", :include_declaration} => bool()
    })
  end
end
