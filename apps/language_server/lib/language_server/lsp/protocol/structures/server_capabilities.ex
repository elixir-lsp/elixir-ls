# codegen: do not edit
defmodule GenLSP.Structures.ServerCapabilities do
  @moduledoc """
  Defines the capabilities provided by a language
  server.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * position_encoding: The position encoding the server picked from the encodings offered
    by the client via the client capability `general.positionEncodings`.

    If the client didn't provide any position encodings the only valid
    value that a server can return is 'utf-16'.

    If omitted it defaults to 'utf-16'.

    @since 3.17.0
  * text_document_sync: Defines how text documents are synced. Is either a detailed structure
    defining each notification or for backwards compatibility the
    TextDocumentSyncKind number.
  * notebook_document_sync: Defines how notebook documents are synced.

    @since 3.17.0
  * completion_provider: The server provides completion support.
  * hover_provider: The server provides hover support.
  * signature_help_provider: The server provides signature help support.
  * declaration_provider: The server provides Goto Declaration support.
  * definition_provider: The server provides goto definition support.
  * type_definition_provider: The server provides Goto Type Definition support.
  * implementation_provider: The server provides Goto Implementation support.
  * references_provider: The server provides find references support.
  * document_highlight_provider: The server provides document highlight support.
  * document_symbol_provider: The server provides document symbol support.
  * code_action_provider: The server provides code actions. CodeActionOptions may only be
    specified if the client states that it supports
    `codeActionLiteralSupport` in its initial `initialize` request.
  * code_lens_provider: The server provides code lens.
  * document_link_provider: The server provides document link support.
  * color_provider: The server provides color provider support.
  * workspace_symbol_provider: The server provides workspace symbol support.
  * document_formatting_provider: The server provides document formatting.
  * document_range_formatting_provider: The server provides document range formatting.
  * document_on_type_formatting_provider: The server provides document formatting on typing.
  * rename_provider: The server provides rename support. RenameOptions may only be
    specified if the client states that it supports
    `prepareSupport` in its initial `initialize` request.
  * folding_range_provider: The server provides folding provider support.
  * selection_range_provider: The server provides selection range support.
  * execute_command_provider: The server provides execute command support.
  * call_hierarchy_provider: The server provides call hierarchy support.

    @since 3.16.0
  * linked_editing_range_provider: The server provides linked editing range support.

    @since 3.16.0
  * semantic_tokens_provider: The server provides semantic tokens support.

    @since 3.16.0
  * moniker_provider: The server provides moniker support.

    @since 3.16.0
  * type_hierarchy_provider: The server provides type hierarchy support.

    @since 3.17.0
  * inline_value_provider: The server provides inline values.

    @since 3.17.0
  * inlay_hint_provider: The server provides inlay hints.

    @since 3.17.0
  * diagnostic_provider: The server has support for pull model diagnostics.

    @since 3.17.0
  * workspace: Workspace specific server capabilities.
  * experimental: Experimental server capabilities.
  """
  
  typedstruct do
    field :position_encoding, GenLSP.Enumerations.PositionEncodingKind.t()

    field :text_document_sync,
          GenLSP.Structures.TextDocumentSyncOptions.t()
          | GenLSP.Enumerations.TextDocumentSyncKind.t()

    field :notebook_document_sync,
          GenLSP.Structures.NotebookDocumentSyncOptions.t()
          | GenLSP.Structures.NotebookDocumentSyncRegistrationOptions.t()

    field :completion_provider, GenLSP.Structures.CompletionOptions.t()
    field :hover_provider, boolean() | GenLSP.Structures.HoverOptions.t()
    field :signature_help_provider, GenLSP.Structures.SignatureHelpOptions.t()

    field :declaration_provider,
          boolean()
          | GenLSP.Structures.DeclarationOptions.t()
          | GenLSP.Structures.DeclarationRegistrationOptions.t()

    field :definition_provider, boolean() | GenLSP.Structures.DefinitionOptions.t()

    field :type_definition_provider,
          boolean()
          | GenLSP.Structures.TypeDefinitionOptions.t()
          | GenLSP.Structures.TypeDefinitionRegistrationOptions.t()

    field :implementation_provider,
          boolean()
          | GenLSP.Structures.ImplementationOptions.t()
          | GenLSP.Structures.ImplementationRegistrationOptions.t()

    field :references_provider, boolean() | GenLSP.Structures.ReferenceOptions.t()
    field :document_highlight_provider, boolean() | GenLSP.Structures.DocumentHighlightOptions.t()
    field :document_symbol_provider, boolean() | GenLSP.Structures.DocumentSymbolOptions.t()
    field :code_action_provider, boolean() | GenLSP.Structures.CodeActionOptions.t()
    field :code_lens_provider, GenLSP.Structures.CodeLensOptions.t()
    field :document_link_provider, GenLSP.Structures.DocumentLinkOptions.t()

    field :color_provider,
          boolean()
          | GenLSP.Structures.DocumentColorOptions.t()
          | GenLSP.Structures.DocumentColorRegistrationOptions.t()

    field :workspace_symbol_provider, boolean() | GenLSP.Structures.WorkspaceSymbolOptions.t()

    field :document_formatting_provider,
          boolean() | GenLSP.Structures.DocumentFormattingOptions.t()

    field :document_range_formatting_provider,
          boolean() | GenLSP.Structures.DocumentRangeFormattingOptions.t()

    field :document_on_type_formatting_provider,
          GenLSP.Structures.DocumentOnTypeFormattingOptions.t()

    field :rename_provider, boolean() | GenLSP.Structures.RenameOptions.t()

    field :folding_range_provider,
          boolean()
          | GenLSP.Structures.FoldingRangeOptions.t()
          | GenLSP.Structures.FoldingRangeRegistrationOptions.t()

    field :selection_range_provider,
          boolean()
          | GenLSP.Structures.SelectionRangeOptions.t()
          | GenLSP.Structures.SelectionRangeRegistrationOptions.t()

    field :execute_command_provider, GenLSP.Structures.ExecuteCommandOptions.t()

    field :call_hierarchy_provider,
          boolean()
          | GenLSP.Structures.CallHierarchyOptions.t()
          | GenLSP.Structures.CallHierarchyRegistrationOptions.t()

    field :linked_editing_range_provider,
          boolean()
          | GenLSP.Structures.LinkedEditingRangeOptions.t()
          | GenLSP.Structures.LinkedEditingRangeRegistrationOptions.t()

    field :semantic_tokens_provider,
          GenLSP.Structures.SemanticTokensOptions.t()
          | GenLSP.Structures.SemanticTokensRegistrationOptions.t()

    field :moniker_provider,
          boolean()
          | GenLSP.Structures.MonikerOptions.t()
          | GenLSP.Structures.MonikerRegistrationOptions.t()

    field :type_hierarchy_provider,
          boolean()
          | GenLSP.Structures.TypeHierarchyOptions.t()
          | GenLSP.Structures.TypeHierarchyRegistrationOptions.t()

    field :inline_value_provider,
          boolean()
          | GenLSP.Structures.InlineValueOptions.t()
          | GenLSP.Structures.InlineValueRegistrationOptions.t()

    field :inlay_hint_provider,
          boolean()
          | GenLSP.Structures.InlayHintOptions.t()
          | GenLSP.Structures.InlayHintRegistrationOptions.t()

    field :diagnostic_provider,
          GenLSP.Structures.DiagnosticOptions.t()
          | GenLSP.Structures.DiagnosticRegistrationOptions.t()

    field :workspace, map()
    field :experimental, GenLSP.TypeAlias.LSPAny.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"positionEncoding", :position_encoding}) =>
        GenLSP.Enumerations.PositionEncodingKind.schematic(),
      optional({"textDocumentSync", :text_document_sync}) =>
        oneof([
          GenLSP.Structures.TextDocumentSyncOptions.schematic(),
          GenLSP.Enumerations.TextDocumentSyncKind.schematic()
        ]),
      optional({"notebookDocumentSync", :notebook_document_sync}) =>
        oneof([
          GenLSP.Structures.NotebookDocumentSyncOptions.schematic(),
          GenLSP.Structures.NotebookDocumentSyncRegistrationOptions.schematic()
        ]),
      optional({"completionProvider", :completion_provider}) =>
        GenLSP.Structures.CompletionOptions.schematic(),
      optional({"hoverProvider", :hover_provider}) =>
        oneof([bool(), GenLSP.Structures.HoverOptions.schematic()]),
      optional({"signatureHelpProvider", :signature_help_provider}) =>
        GenLSP.Structures.SignatureHelpOptions.schematic(),
      optional({"declarationProvider", :declaration_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.DeclarationOptions.schematic(),
          GenLSP.Structures.DeclarationRegistrationOptions.schematic()
        ]),
      optional({"definitionProvider", :definition_provider}) =>
        oneof([bool(), GenLSP.Structures.DefinitionOptions.schematic()]),
      optional({"typeDefinitionProvider", :type_definition_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.TypeDefinitionOptions.schematic(),
          GenLSP.Structures.TypeDefinitionRegistrationOptions.schematic()
        ]),
      optional({"implementationProvider", :implementation_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.ImplementationOptions.schematic(),
          GenLSP.Structures.ImplementationRegistrationOptions.schematic()
        ]),
      optional({"referencesProvider", :references_provider}) =>
        oneof([bool(), GenLSP.Structures.ReferenceOptions.schematic()]),
      optional({"documentHighlightProvider", :document_highlight_provider}) =>
        oneof([bool(), GenLSP.Structures.DocumentHighlightOptions.schematic()]),
      optional({"documentSymbolProvider", :document_symbol_provider}) =>
        oneof([bool(), GenLSP.Structures.DocumentSymbolOptions.schematic()]),
      optional({"codeActionProvider", :code_action_provider}) =>
        oneof([bool(), GenLSP.Structures.CodeActionOptions.schematic()]),
      optional({"codeLensProvider", :code_lens_provider}) =>
        GenLSP.Structures.CodeLensOptions.schematic(),
      optional({"documentLinkProvider", :document_link_provider}) =>
        GenLSP.Structures.DocumentLinkOptions.schematic(),
      optional({"colorProvider", :color_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.DocumentColorOptions.schematic(),
          GenLSP.Structures.DocumentColorRegistrationOptions.schematic()
        ]),
      optional({"workspaceSymbolProvider", :workspace_symbol_provider}) =>
        oneof([bool(), GenLSP.Structures.WorkspaceSymbolOptions.schematic()]),
      optional({"documentFormattingProvider", :document_formatting_provider}) =>
        oneof([bool(), GenLSP.Structures.DocumentFormattingOptions.schematic()]),
      optional({"documentRangeFormattingProvider", :document_range_formatting_provider}) =>
        oneof([bool(), GenLSP.Structures.DocumentRangeFormattingOptions.schematic()]),
      optional({"documentOnTypeFormattingProvider", :document_on_type_formatting_provider}) =>
        GenLSP.Structures.DocumentOnTypeFormattingOptions.schematic(),
      optional({"renameProvider", :rename_provider}) =>
        oneof([bool(), GenLSP.Structures.RenameOptions.schematic()]),
      optional({"foldingRangeProvider", :folding_range_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.FoldingRangeOptions.schematic(),
          GenLSP.Structures.FoldingRangeRegistrationOptions.schematic()
        ]),
      optional({"selectionRangeProvider", :selection_range_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.SelectionRangeOptions.schematic(),
          GenLSP.Structures.SelectionRangeRegistrationOptions.schematic()
        ]),
      optional({"executeCommandProvider", :execute_command_provider}) =>
        GenLSP.Structures.ExecuteCommandOptions.schematic(),
      optional({"callHierarchyProvider", :call_hierarchy_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.CallHierarchyOptions.schematic(),
          GenLSP.Structures.CallHierarchyRegistrationOptions.schematic()
        ]),
      optional({"linkedEditingRangeProvider", :linked_editing_range_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.LinkedEditingRangeOptions.schematic(),
          GenLSP.Structures.LinkedEditingRangeRegistrationOptions.schematic()
        ]),
      optional({"semanticTokensProvider", :semantic_tokens_provider}) =>
        oneof([
          GenLSP.Structures.SemanticTokensOptions.schematic(),
          GenLSP.Structures.SemanticTokensRegistrationOptions.schematic()
        ]),
      optional({"monikerProvider", :moniker_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.MonikerOptions.schematic(),
          GenLSP.Structures.MonikerRegistrationOptions.schematic()
        ]),
      optional({"typeHierarchyProvider", :type_hierarchy_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.TypeHierarchyOptions.schematic(),
          GenLSP.Structures.TypeHierarchyRegistrationOptions.schematic()
        ]),
      optional({"inlineValueProvider", :inline_value_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.InlineValueOptions.schematic(),
          GenLSP.Structures.InlineValueRegistrationOptions.schematic()
        ]),
      optional({"inlayHintProvider", :inlay_hint_provider}) =>
        oneof([
          bool(),
          GenLSP.Structures.InlayHintOptions.schematic(),
          GenLSP.Structures.InlayHintRegistrationOptions.schematic()
        ]),
      optional({"diagnosticProvider", :diagnostic_provider}) =>
        oneof([
          GenLSP.Structures.DiagnosticOptions.schematic(),
          GenLSP.Structures.DiagnosticRegistrationOptions.schematic()
        ]),
      optional({"workspace", :workspace}) =>
        map(%{
          optional({"workspaceFolders", :workspace_folders}) =>
            GenLSP.Structures.WorkspaceFoldersServerCapabilities.schematic(),
          optional({"fileOperations", :file_operations}) =>
            GenLSP.Structures.FileOperationOptions.schematic()
        }),
      optional({"experimental", :experimental}) => GenLSP.TypeAlias.LSPAny.schematic()
    })
  end
end
