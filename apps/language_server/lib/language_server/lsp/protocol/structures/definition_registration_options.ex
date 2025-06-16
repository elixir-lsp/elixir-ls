# codegen: do not edit
defmodule GenLSP.Structures.DefinitionRegistrationOptions do
  @moduledoc """
  Registration options for a {@link DefinitionRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  """

  typedstruct do
    field(:document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil])
    })
  end
end
