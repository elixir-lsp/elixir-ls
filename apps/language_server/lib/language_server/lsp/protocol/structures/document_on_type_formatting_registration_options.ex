# codegen: do not edit
defmodule GenLSP.Structures.DocumentOnTypeFormattingRegistrationOptions do
  @moduledoc """
  Registration options for a {@link DocumentOnTypeFormattingRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  * first_trigger_character: A character on which formatting should be triggered, like `{`.
  * more_trigger_character: More trigger characters.
  """
  
  typedstruct do
    field :document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true
    field :first_trigger_character, String.t(), enforce: true
    field :more_trigger_character, list(String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil]),
      {"firstTriggerCharacter", :first_trigger_character} => str(),
      optional({"moreTriggerCharacter", :more_trigger_character}) => list(str())
    })
  end
end
