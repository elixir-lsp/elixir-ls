# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Document.Symbol.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types

  defmodule SymbolKind do
    use Proto
    deftype value_set: optional(list_of(Types.Symbol.Kind))
  end

  defmodule TagSupport do
    use Proto
    deftype value_set: list_of(Types.Symbol.Tag)
  end

  use Proto

  deftype dynamic_registration: optional(boolean()),
          hierarchical_document_symbol_support: optional(boolean()),
          label_support: optional(boolean()),
          symbol_kind: optional(SymbolKind),
          tag_support: optional(TagSupport)
end
