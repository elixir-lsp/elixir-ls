# codegen: do not edit
defmodule GenLSP.Requests do
  import SchematicV

  def new(request) do
    unify(
      oneof(fn
        %{"method" => "callHierarchy/incomingCalls"} ->
          GenLSP.Requests.CallHierarchyIncomingCalls.schematic()

        %{"method" => "callHierarchy/outgoingCalls"} ->
          GenLSP.Requests.CallHierarchyOutgoingCalls.schematic()

        %{"method" => "client/registerCapability"} ->
          GenLSP.Requests.ClientRegisterCapability.schematic()

        %{"method" => "client/unregisterCapability"} ->
          GenLSP.Requests.ClientUnregisterCapability.schematic()

        %{"method" => "codeAction/resolve"} ->
          GenLSP.Requests.CodeActionResolve.schematic()

        %{"method" => "codeLens/resolve"} ->
          GenLSP.Requests.CodeLensResolve.schematic()

        %{"method" => "completionItem/resolve"} ->
          GenLSP.Requests.CompletionItemResolve.schematic()

        %{"method" => "documentLink/resolve"} ->
          GenLSP.Requests.DocumentLinkResolve.schematic()

        %{"method" => "initialize"} ->
          GenLSP.Requests.Initialize.schematic()

        %{"method" => "inlayHint/resolve"} ->
          GenLSP.Requests.InlayHintResolve.schematic()

        %{"method" => "shutdown"} ->
          GenLSP.Requests.Shutdown.schematic()

        %{"method" => "textDocument/codeAction"} ->
          GenLSP.Requests.TextDocumentCodeAction.schematic()

        %{"method" => "textDocument/codeLens"} ->
          GenLSP.Requests.TextDocumentCodeLens.schematic()

        %{"method" => "textDocument/colorPresentation"} ->
          GenLSP.Requests.TextDocumentColorPresentation.schematic()

        %{"method" => "textDocument/completion"} ->
          GenLSP.Requests.TextDocumentCompletion.schematic()

        %{"method" => "textDocument/declaration"} ->
          GenLSP.Requests.TextDocumentDeclaration.schematic()

        %{"method" => "textDocument/definition"} ->
          GenLSP.Requests.TextDocumentDefinition.schematic()

        %{"method" => "textDocument/diagnostic"} ->
          GenLSP.Requests.TextDocumentDiagnostic.schematic()

        %{"method" => "textDocument/documentColor"} ->
          GenLSP.Requests.TextDocumentDocumentColor.schematic()

        %{"method" => "textDocument/documentHighlight"} ->
          GenLSP.Requests.TextDocumentDocumentHighlight.schematic()

        %{"method" => "textDocument/documentLink"} ->
          GenLSP.Requests.TextDocumentDocumentLink.schematic()

        %{"method" => "textDocument/documentSymbol"} ->
          GenLSP.Requests.TextDocumentDocumentSymbol.schematic()

        %{"method" => "textDocument/foldingRange"} ->
          GenLSP.Requests.TextDocumentFoldingRange.schematic()

        %{"method" => "textDocument/formatting"} ->
          GenLSP.Requests.TextDocumentFormatting.schematic()

        %{"method" => "textDocument/hover"} ->
          GenLSP.Requests.TextDocumentHover.schematic()

        %{"method" => "textDocument/implementation"} ->
          GenLSP.Requests.TextDocumentImplementation.schematic()

        %{"method" => "textDocument/inlayHint"} ->
          GenLSP.Requests.TextDocumentInlayHint.schematic()

        %{"method" => "textDocument/inlineValue"} ->
          GenLSP.Requests.TextDocumentInlineValue.schematic()

        %{"method" => "textDocument/linkedEditingRange"} ->
          GenLSP.Requests.TextDocumentLinkedEditingRange.schematic()

        %{"method" => "textDocument/moniker"} ->
          GenLSP.Requests.TextDocumentMoniker.schematic()

        %{"method" => "textDocument/onTypeFormatting"} ->
          GenLSP.Requests.TextDocumentOnTypeFormatting.schematic()

        %{"method" => "textDocument/prepareCallHierarchy"} ->
          GenLSP.Requests.TextDocumentPrepareCallHierarchy.schematic()

        %{"method" => "textDocument/prepareRename"} ->
          GenLSP.Requests.TextDocumentPrepareRename.schematic()

        %{"method" => "textDocument/prepareTypeHierarchy"} ->
          GenLSP.Requests.TextDocumentPrepareTypeHierarchy.schematic()

        %{"method" => "textDocument/rangeFormatting"} ->
          GenLSP.Requests.TextDocumentRangeFormatting.schematic()

        %{"method" => "textDocument/references"} ->
          GenLSP.Requests.TextDocumentReferences.schematic()

        %{"method" => "textDocument/rename"} ->
          GenLSP.Requests.TextDocumentRename.schematic()

        %{"method" => "textDocument/selectionRange"} ->
          GenLSP.Requests.TextDocumentSelectionRange.schematic()

        %{"method" => "textDocument/semanticTokens/full"} ->
          GenLSP.Requests.TextDocumentSemanticTokensFull.schematic()

        %{"method" => "textDocument/semanticTokens/full/delta"} ->
          GenLSP.Requests.TextDocumentSemanticTokensFullDelta.schematic()

        %{"method" => "textDocument/semanticTokens/range"} ->
          GenLSP.Requests.TextDocumentSemanticTokensRange.schematic()

        %{"method" => "textDocument/signatureHelp"} ->
          GenLSP.Requests.TextDocumentSignatureHelp.schematic()

        %{"method" => "textDocument/typeDefinition"} ->
          GenLSP.Requests.TextDocumentTypeDefinition.schematic()

        %{"method" => "textDocument/willSaveWaitUntil"} ->
          GenLSP.Requests.TextDocumentWillSaveWaitUntil.schematic()

        %{"method" => "typeHierarchy/subtypes"} ->
          GenLSP.Requests.TypeHierarchySubtypes.schematic()

        %{"method" => "typeHierarchy/supertypes"} ->
          GenLSP.Requests.TypeHierarchySupertypes.schematic()

        %{"method" => "window/showDocument"} ->
          GenLSP.Requests.WindowShowDocument.schematic()

        %{"method" => "window/showMessageRequest"} ->
          GenLSP.Requests.WindowShowMessageRequest.schematic()

        %{"method" => "window/workDoneProgress/create"} ->
          GenLSP.Requests.WindowWorkDoneProgressCreate.schematic()

        %{"method" => "workspace/applyEdit"} ->
          GenLSP.Requests.WorkspaceApplyEdit.schematic()

        %{"method" => "workspace/codeLens/refresh"} ->
          GenLSP.Requests.WorkspaceCodeLensRefresh.schematic()

        %{"method" => "workspace/configuration"} ->
          GenLSP.Requests.WorkspaceConfiguration.schematic()

        %{"method" => "workspace/diagnostic"} ->
          GenLSP.Requests.WorkspaceDiagnostic.schematic()

        %{"method" => "workspace/diagnostic/refresh"} ->
          GenLSP.Requests.WorkspaceDiagnosticRefresh.schematic()

        %{"method" => "workspace/executeCommand"} ->
          GenLSP.Requests.WorkspaceExecuteCommand.schematic()

        %{"method" => "workspace/inlayHint/refresh"} ->
          GenLSP.Requests.WorkspaceInlayHintRefresh.schematic()

        %{"method" => "workspace/inlineValue/refresh"} ->
          GenLSP.Requests.WorkspaceInlineValueRefresh.schematic()

        %{"method" => "workspace/semanticTokens/refresh"} ->
          GenLSP.Requests.WorkspaceSemanticTokensRefresh.schematic()

        %{"method" => "workspace/symbol"} ->
          GenLSP.Requests.WorkspaceSymbol.schematic()

        %{"method" => "workspace/willCreateFiles"} ->
          GenLSP.Requests.WorkspaceWillCreateFiles.schematic()

        %{"method" => "workspace/willDeleteFiles"} ->
          GenLSP.Requests.WorkspaceWillDeleteFiles.schematic()

        %{"method" => "workspace/willRenameFiles"} ->
          GenLSP.Requests.WorkspaceWillRenameFiles.schematic()

        %{"method" => "workspace/workspaceFolders"} ->
          GenLSP.Requests.WorkspaceWorkspaceFolders.schematic()

        %{"method" => "workspaceSymbol/resolve"} ->
          GenLSP.Requests.WorkspaceSymbolResolve.schematic()

        _ ->
          {:error, "unexpected request payload"}
      end),
      request
    )
  end
end
