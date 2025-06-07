# codegen: do not edit
defmodule GenLSP.Structures.SignatureHelpContext do
  @moduledoc """
  Additional information about the context in which a signature help request was triggered.

  @since 3.15.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * trigger_kind: Action that caused signature help to be triggered.
  * trigger_character: Character that caused signature help to be triggered.

    This is undefined when `triggerKind !== SignatureHelpTriggerKind.TriggerCharacter`
  * is_retrigger: `true` if signature help was already showing when it was triggered.

    Retriggers occurs when the signature help is already active and can be caused by actions such as
    typing a trigger character, a cursor move, or document content changes.
  * active_signature_help: The currently active `SignatureHelp`.

    The `activeSignatureHelp` has its `SignatureHelp.activeSignature` field updated based on
    the user navigating through available signatures.
  """
  
  typedstruct do
    field :trigger_kind, GenLSP.Enumerations.SignatureHelpTriggerKind.t(), enforce: true
    field :trigger_character, String.t()
    field :is_retrigger, boolean(), enforce: true
    field :active_signature_help, GenLSP.Structures.SignatureHelp.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"triggerKind", :trigger_kind} => GenLSP.Enumerations.SignatureHelpTriggerKind.schematic(),
      optional({"triggerCharacter", :trigger_character}) => str(),
      {"isRetrigger", :is_retrigger} => bool(),
      optional({"activeSignatureHelp", :active_signature_help}) =>
        GenLSP.Structures.SignatureHelp.schematic()
    })
  end
end
