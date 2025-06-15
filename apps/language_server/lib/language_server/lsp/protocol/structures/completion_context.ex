# codegen: do not edit
defmodule GenLSP.Structures.CompletionContext do
  @moduledoc """
  Contains additional information about the context in which a completion request is triggered.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * trigger_kind: How the completion was triggered.
  * trigger_character: The trigger character (a single character) that has trigger code complete.
    Is undefined if `triggerKind !== CompletionTriggerKind.TriggerCharacter`
  """

  typedstruct do
    field(:trigger_kind, GenLSP.Enumerations.CompletionTriggerKind.t(), enforce: true)
    field(:trigger_character, String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"triggerKind", :trigger_kind} => GenLSP.Enumerations.CompletionTriggerKind.schematic(),
      optional({"triggerCharacter", :trigger_character}) => str()
    })
  end
end
