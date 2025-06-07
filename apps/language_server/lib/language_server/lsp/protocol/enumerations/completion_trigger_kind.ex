# codegen: do not edit
defmodule GenLSP.Enumerations.CompletionTriggerKind do
  @moduledoc """
  How a completion was triggered
  """

  @type t :: 1 | 2 | 3

  import Schematic, warn: false

  @doc """
  Completion was triggered by typing an identifier (24x7 code
  complete), manual invocation (e.g Ctrl+Space) or via API.
  """
  @spec invoked() :: 1
  def invoked, do: 1

  @doc """
  Completion was triggered by a trigger character specified by
  the `triggerCharacters` properties of the `CompletionRegistrationOptions`.
  """
  @spec trigger_character() :: 2
  def trigger_character, do: 2

  @doc """
  Completion was re-triggered as current completion list is incomplete
  """
  @spec trigger_for_incomplete_completions() :: 3
  def trigger_for_incomplete_completions, do: 3

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      1,
      2,
      3
    ])
  end
end
