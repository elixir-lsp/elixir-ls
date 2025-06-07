# codegen: do not edit
defmodule GenLSP.Structures.CompletionClientCapabilities do
  @moduledoc """
  Completion client capabilities
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether completion supports dynamic registration.
  * completion_item: The client supports the following `CompletionItem` specific
    capabilities.
  * completion_item_kind
  * insert_text_mode: Defines how the client handles whitespace and indentation
    when accepting a completion item that uses multi line
    text in either `insertText` or `textEdit`.

    @since 3.17.0
  * context_support: The client supports to send additional context information for a
    `textDocument/completion` request.
  * completion_list: The client supports the following `CompletionList` specific
    capabilities.

    @since 3.17.0
  """
  
  typedstruct do
    field :dynamic_registration, boolean()
    field :completion_item, map()
    field :completion_item_kind, map()
    field :insert_text_mode, GenLSP.Enumerations.InsertTextMode.t()
    field :context_support, boolean()
    field :completion_list, map()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"completionItem", :completion_item}) =>
        map(%{
          optional({"snippetSupport", :snippet_support}) => bool(),
          optional({"commitCharactersSupport", :commit_characters_support}) => bool(),
          optional({"documentationFormat", :documentation_format}) =>
            list(GenLSP.Enumerations.MarkupKind.schematic()),
          optional({"deprecatedSupport", :deprecated_support}) => bool(),
          optional({"preselectSupport", :preselect_support}) => bool(),
          optional({"tagSupport", :tag_support}) =>
            map(%{
              {"valueSet", :value_set} => list(GenLSP.Enumerations.CompletionItemTag.schematic())
            }),
          optional({"insertReplaceSupport", :insert_replace_support}) => bool(),
          optional({"resolveSupport", :resolve_support}) =>
            map(%{
              {"properties", :properties} => list(str())
            }),
          optional({"insertTextModeSupport", :insert_text_mode_support}) =>
            map(%{
              {"valueSet", :value_set} => list(GenLSP.Enumerations.InsertTextMode.schematic())
            }),
          optional({"labelDetailsSupport", :label_details_support}) => bool()
        }),
      optional({"completionItemKind", :completion_item_kind}) =>
        map(%{
          optional({"valueSet", :value_set}) =>
            list(GenLSP.Enumerations.CompletionItemKind.schematic())
        }),
      optional({"insertTextMode", :insert_text_mode}) =>
        GenLSP.Enumerations.InsertTextMode.schematic(),
      optional({"contextSupport", :context_support}) => bool(),
      optional({"completionList", :completion_list}) =>
        map(%{
          optional({"itemDefaults", :item_defaults}) => list(str())
        })
    })
  end
end
