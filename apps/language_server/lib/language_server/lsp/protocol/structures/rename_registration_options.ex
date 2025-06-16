# codegen: do not edit
defmodule GenLSP.Structures.RenameRegistrationOptions do
  @moduledoc """
  Registration options for a {@link RenameRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  * prepare_provider: Renames should be checked and tested before being executed.

    @since version 3.12.0
  """

  typedstruct do
    field(:document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true)
    field(:prepare_provider, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil]),
      optional({"prepareProvider", :prepare_provider}) => bool()
    })
  end
end
