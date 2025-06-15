# codegen: do not edit
defmodule GenLSP.Structures.SignatureHelpRegistrationOptions do
  @moduledoc """
  Registration options for a {@link SignatureHelpRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  * trigger_characters: List of characters that trigger signature help automatically.
  * retrigger_characters: List of characters that re-trigger signature help.

    These trigger characters are only active when signature help is already showing. All trigger characters
    are also counted as re-trigger characters.

    @since 3.15.0
  """

  typedstruct do
    field(:document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true)
    field(:trigger_characters, list(String.t()))
    field(:retrigger_characters, list(String.t()))
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil]),
      optional({"triggerCharacters", :trigger_characters}) => list(str()),
      optional({"retriggerCharacters", :retrigger_characters}) => list(str())
    })
  end
end
