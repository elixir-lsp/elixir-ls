# codegen: do not edit
defmodule GenLSP.Structures.TextDocumentClientCapabilities do
  @moduledoc """
  Text document specific client capabilities.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * synchronization: Defines which synchronization capabilities the client supports.
  * completion: Capabilities specific to the `textDocument/completion` request.
  * hover: Capabilities specific to the `textDocument/hover` request.
  * signature_help: Capabilities specific to the `textDocument/signatureHelp` request.
  * declaration: Capabilities specific to the `textDocument/declaration` request.

    @since 3.14.0
  * definition: Capabilities specific to the `textDocument/definition` request.
  * type_definition: Capabilities specific to the `textDocument/typeDefinition` request.

    @since 3.6.0
  * implementation: Capabilities specific to the `textDocument/implementation` request.

    @since 3.6.0
  * references: Capabilities specific to the `textDocument/references` request.
  * document_highlight: Capabilities specific to the `textDocument/documentHighlight` request.
  * document_symbol: Capabilities specific to the `textDocument/documentSymbol` request.
  * code_action: Capabilities specific to the `textDocument/codeAction` request.
  * code_lens: Capabilities specific to the `textDocument/codeLens` request.
  * document_link: Capabilities specific to the `textDocument/documentLink` request.
  * color_provider: Capabilities specific to the `textDocument/documentColor` and the
    `textDocument/colorPresentation` request.

    @since 3.6.0
  * formatting: Capabilities specific to the `textDocument/formatting` request.
  * range_formatting: Capabilities specific to the `textDocument/rangeFormatting` request.
  * on_type_formatting: Capabilities specific to the `textDocument/onTypeFormatting` request.
  * rename: Capabilities specific to the `textDocument/rename` request.
  * folding_range: Capabilities specific to the `textDocument/foldingRange` request.

    @since 3.10.0
  * selection_range: Capabilities specific to the `textDocument/selectionRange` request.

    @since 3.15.0
  * publish_diagnostics: Capabilities specific to the `textDocument/publishDiagnostics` notification.
  * call_hierarchy: Capabilities specific to the various call hierarchy requests.

    @since 3.16.0
  * semantic_tokens: Capabilities specific to the various semantic token request.

    @since 3.16.0
  * linked_editing_range: Capabilities specific to the `textDocument/linkedEditingRange` request.

    @since 3.16.0
  * moniker: Client capabilities specific to the `textDocument/moniker` request.

    @since 3.16.0
  * type_hierarchy: Capabilities specific to the various type hierarchy requests.

    @since 3.17.0
  * inline_value: Capabilities specific to the `textDocument/inlineValue` request.

    @since 3.17.0
  * inlay_hint: Capabilities specific to the `textDocument/inlayHint` request.

    @since 3.17.0
  * diagnostic: Capabilities specific to the diagnostic pull model.

    @since 3.17.0
  """

  typedstruct do
    field(:synchronization, GenLSP.Structures.TextDocumentSyncClientCapabilities.t())
    field(:completion, GenLSP.Structures.CompletionClientCapabilities.t())
    field(:hover, GenLSP.Structures.HoverClientCapabilities.t())
    field(:signature_help, GenLSP.Structures.SignatureHelpClientCapabilities.t())
    field(:declaration, GenLSP.Structures.DeclarationClientCapabilities.t())
    field(:definition, GenLSP.Structures.DefinitionClientCapabilities.t())
    field(:type_definition, GenLSP.Structures.TypeDefinitionClientCapabilities.t())
    field(:implementation, GenLSP.Structures.ImplementationClientCapabilities.t())
    field(:references, GenLSP.Structures.ReferenceClientCapabilities.t())
    field(:document_highlight, GenLSP.Structures.DocumentHighlightClientCapabilities.t())
    field(:document_symbol, GenLSP.Structures.DocumentSymbolClientCapabilities.t())
    field(:code_action, GenLSP.Structures.CodeActionClientCapabilities.t())
    field(:code_lens, GenLSP.Structures.CodeLensClientCapabilities.t())
    field(:document_link, GenLSP.Structures.DocumentLinkClientCapabilities.t())
    field(:color_provider, GenLSP.Structures.DocumentColorClientCapabilities.t())
    field(:formatting, GenLSP.Structures.DocumentFormattingClientCapabilities.t())
    field(:range_formatting, GenLSP.Structures.DocumentRangeFormattingClientCapabilities.t())
    field(:on_type_formatting, GenLSP.Structures.DocumentOnTypeFormattingClientCapabilities.t())
    field(:rename, GenLSP.Structures.RenameClientCapabilities.t())
    field(:folding_range, GenLSP.Structures.FoldingRangeClientCapabilities.t())
    field(:selection_range, GenLSP.Structures.SelectionRangeClientCapabilities.t())
    field(:publish_diagnostics, GenLSP.Structures.PublishDiagnosticsClientCapabilities.t())
    field(:call_hierarchy, GenLSP.Structures.CallHierarchyClientCapabilities.t())
    field(:semantic_tokens, GenLSP.Structures.SemanticTokensClientCapabilities.t())
    field(:linked_editing_range, GenLSP.Structures.LinkedEditingRangeClientCapabilities.t())
    field(:moniker, GenLSP.Structures.MonikerClientCapabilities.t())
    field(:type_hierarchy, GenLSP.Structures.TypeHierarchyClientCapabilities.t())
    field(:inline_value, GenLSP.Structures.InlineValueClientCapabilities.t())
    field(:inlay_hint, GenLSP.Structures.InlayHintClientCapabilities.t())
    field(:diagnostic, GenLSP.Structures.DiagnosticClientCapabilities.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"synchronization", :synchronization}) =>
        GenLSP.Structures.TextDocumentSyncClientCapabilities.schematic(),
      optional({"completion", :completion}) =>
        GenLSP.Structures.CompletionClientCapabilities.schematic(),
      optional({"hover", :hover}) => GenLSP.Structures.HoverClientCapabilities.schematic(),
      optional({"signatureHelp", :signature_help}) =>
        GenLSP.Structures.SignatureHelpClientCapabilities.schematic(),
      optional({"declaration", :declaration}) =>
        GenLSP.Structures.DeclarationClientCapabilities.schematic(),
      optional({"definition", :definition}) =>
        GenLSP.Structures.DefinitionClientCapabilities.schematic(),
      optional({"typeDefinition", :type_definition}) =>
        GenLSP.Structures.TypeDefinitionClientCapabilities.schematic(),
      optional({"implementation", :implementation}) =>
        GenLSP.Structures.ImplementationClientCapabilities.schematic(),
      optional({"references", :references}) =>
        GenLSP.Structures.ReferenceClientCapabilities.schematic(),
      optional({"documentHighlight", :document_highlight}) =>
        GenLSP.Structures.DocumentHighlightClientCapabilities.schematic(),
      optional({"documentSymbol", :document_symbol}) =>
        GenLSP.Structures.DocumentSymbolClientCapabilities.schematic(),
      optional({"codeAction", :code_action}) =>
        GenLSP.Structures.CodeActionClientCapabilities.schematic(),
      optional({"codeLens", :code_lens}) =>
        GenLSP.Structures.CodeLensClientCapabilities.schematic(),
      optional({"documentLink", :document_link}) =>
        GenLSP.Structures.DocumentLinkClientCapabilities.schematic(),
      optional({"colorProvider", :color_provider}) =>
        GenLSP.Structures.DocumentColorClientCapabilities.schematic(),
      optional({"formatting", :formatting}) =>
        GenLSP.Structures.DocumentFormattingClientCapabilities.schematic(),
      optional({"rangeFormatting", :range_formatting}) =>
        GenLSP.Structures.DocumentRangeFormattingClientCapabilities.schematic(),
      optional({"onTypeFormatting", :on_type_formatting}) =>
        GenLSP.Structures.DocumentOnTypeFormattingClientCapabilities.schematic(),
      optional({"rename", :rename}) => GenLSP.Structures.RenameClientCapabilities.schematic(),
      optional({"foldingRange", :folding_range}) =>
        GenLSP.Structures.FoldingRangeClientCapabilities.schematic(),
      optional({"selectionRange", :selection_range}) =>
        GenLSP.Structures.SelectionRangeClientCapabilities.schematic(),
      optional({"publishDiagnostics", :publish_diagnostics}) =>
        GenLSP.Structures.PublishDiagnosticsClientCapabilities.schematic(),
      optional({"callHierarchy", :call_hierarchy}) =>
        GenLSP.Structures.CallHierarchyClientCapabilities.schematic(),
      optional({"semanticTokens", :semantic_tokens}) =>
        GenLSP.Structures.SemanticTokensClientCapabilities.schematic(),
      optional({"linkedEditingRange", :linked_editing_range}) =>
        GenLSP.Structures.LinkedEditingRangeClientCapabilities.schematic(),
      optional({"moniker", :moniker}) => GenLSP.Structures.MonikerClientCapabilities.schematic(),
      optional({"typeHierarchy", :type_hierarchy}) =>
        GenLSP.Structures.TypeHierarchyClientCapabilities.schematic(),
      optional({"inlineValue", :inline_value}) =>
        GenLSP.Structures.InlineValueClientCapabilities.schematic(),
      optional({"inlayHint", :inlay_hint}) =>
        GenLSP.Structures.InlayHintClientCapabilities.schematic(),
      optional({"diagnostic", :diagnostic}) =>
        GenLSP.Structures.DiagnosticClientCapabilities.schematic()
    })
  end
end
