# codegen: do not edit
defmodule GenLSP.Structures.CompletionRegistrationOptions do
  @moduledoc """
  Registration options for a {@link CompletionRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  * trigger_characters: Most tools trigger completion request automatically without explicitly requesting
    it using a keyboard shortcut (e.g. Ctrl+Space). Typically they do so when the user
    starts to type an identifier. For example if the user types `c` in a JavaScript file
    code complete will automatically pop up present `console` besides others as a
    completion item. Characters that make up identifiers don't need to be listed here.

    If code complete should automatically be trigger on characters not being valid inside
    an identifier (for example `.` in JavaScript) list them in `triggerCharacters`.
  * all_commit_characters: The list of all possible characters that commit a completion. This field can be used
    if clients don't support individual commit characters per completion item. See
    `ClientCapabilities.textDocument.completion.completionItem.commitCharactersSupport`

    If a server provides both `allCommitCharacters` and commit characters on an individual
    completion item the ones on the completion item win.

    @since 3.2.0
  * resolve_provider: The server provides support to resolve additional
    information for a completion item.
  * completion_item: The server supports the following `CompletionItem` specific
    capabilities.

    @since 3.17.0
  """

  typedstruct do
    field(:document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true)
    field(:trigger_characters, list(String.t()))
    field(:all_commit_characters, list(String.t()))
    field(:resolve_provider, boolean())
    field(:completion_item, map())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil]),
      optional({"triggerCharacters", :trigger_characters}) => list(str()),
      optional({"allCommitCharacters", :all_commit_characters}) => list(str()),
      optional({"resolveProvider", :resolve_provider}) => bool(),
      optional({"completionItem", :completion_item}) =>
        map(%{
          optional({"labelDetailsSupport", :label_details_support}) => bool()
        })
    })
  end
end
