# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Completion.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types

  defmodule CompletionItem do
    use Proto

    deftype commit_characters_support: optional(boolean()),
            deprecated_support: optional(boolean()),
            documentation_format: optional(list_of(Types.Markup.Kind)),
            insert_replace_support: optional(boolean()),
            insert_text_mode_support: optional(InsertTextModeSupport),
            label_details_support: optional(boolean()),
            preselect_support: optional(boolean()),
            resolve_support: optional(ResolveSupport),
            snippet_support: optional(boolean()),
            tag_support: optional(TagSupport)
  end

  defmodule CompletionItemKind do
    use Proto
    deftype value_set: optional(list_of(Types.Completion.Item.Kind))
  end

  defmodule CompletionList do
    use Proto
    deftype item_defaults: optional(list_of(string()))
  end

  defmodule InsertTextModeSupport do
    use Proto
    deftype value_set: list_of(Types.InsertTextMode)
  end

  defmodule ResolveSupport do
    use Proto
    deftype properties: list_of(string())
  end

  defmodule TagSupport do
    use Proto
    deftype value_set: list_of(Types.Completion.Item.Tag)
  end

  use Proto

  deftype completion_item: optional(CompletionItem),
          completion_item_kind: optional(CompletionItemKind),
          completion_list: optional(CompletionList),
          context_support: optional(boolean()),
          dynamic_registration: optional(boolean()),
          insert_text_mode: optional(Types.InsertTextMode)
end
