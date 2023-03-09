# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.TextDocument.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype call_hierarchy: optional(Types.CallHierarchy.ClientCapabilities),
          code_action: optional(Types.CodeAction.ClientCapabilities),
          code_lens: optional(Types.CodeLens.ClientCapabilities),
          color_provider: optional(Types.Document.Color.ClientCapabilities),
          completion: optional(Types.Completion.ClientCapabilities),
          declaration: optional(Types.Declaration.ClientCapabilities),
          definition: optional(Types.Definition.ClientCapabilities),
          diagnostic: optional(Types.Diagnostic.ClientCapabilities),
          document_highlight: optional(Types.Document.Highlight.ClientCapabilities),
          document_link: optional(Types.Document.Link.ClientCapabilities),
          document_symbol: optional(Types.Document.Symbol.ClientCapabilities),
          folding_range: optional(Types.FoldingRange.ClientCapabilities),
          formatting: optional(Types.Document.Formatting.ClientCapabilities),
          hover: optional(Types.Hover.ClientCapabilities),
          implementation: optional(Types.Implementation.ClientCapabilities),
          inlay_hint: optional(Types.InlayHint.ClientCapabilities),
          inline_value: optional(Types.InlineValue.ClientCapabilities),
          linked_editing_range: optional(Types.LinkedEditingRange.ClientCapabilities),
          moniker: optional(Types.Moniker.ClientCapabilities),
          on_type_formatting: optional(Types.Document.OnTypeFormatting.ClientCapabilities),
          publish_diagnostics: optional(Types.PublishDiagnostics.ClientCapabilities),
          range_formatting: optional(Types.Document.RangeFormatting.ClientCapabilities),
          references: optional(Types.Reference.ClientCapabilities),
          rename: optional(Types.Rename.ClientCapabilities),
          selection_range: optional(Types.SelectionRange.ClientCapabilities),
          semantic_tokens: optional(Types.SemanticTokens.ClientCapabilities),
          signature_help: optional(Types.SignatureHelp.ClientCapabilities),
          synchronization: optional(Types.TextDocument.Sync.ClientCapabilities),
          type_definition: optional(Types.TypeDefinition.ClientCapabilities),
          type_hierarchy: optional(Types.TypeHierarchy.ClientCapabilities)
end
