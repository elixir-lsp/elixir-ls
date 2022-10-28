defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto

  defmodule Position do
    use Proto

    deftype line: integer(), character: integer()
  end

  defmodule Range do
    use Proto

    deftype start: Position, end: Position
  end

  defmodule Location do
    use Proto

    deftype uri: uri(), range: Range
  end

  defmodule TextDocument do
    use Proto
    deftype uri: uri(), language_id: string(), version: integer(), text: string()
  end

  defmodule TextDocument.Identifier do
    use Proto

    deftype uri: uri()
  end

  defmodule TextDocument.VersionedIdentifier do
    use Proto

    deftype uri: uri(), version: integer()
  end

  defmodule TextDocument.ContentChangeEvent do
    use Proto

    deftype range: optional(Range), text: string()
  end

  defmodule CodeDescription do
    use Proto

    deftype href: string()
  end

  defmodule Severity do
    use Proto
    defenum error: 1, warning: 2, information: 3, hint: 4
  end

  defmodule DiagnosticTag do
    use Proto

    defenum unnecessary: 1, deprecated: 2
  end

  defmodule DiagnosticRelatedInformation do
    use Proto

    deftype location: Location, message: string()
  end

  defmodule Diagnostic do
    use Proto

    deftype range: Range,
            severity: optional(Severity),
            code: optional(any()),
            code_description: optional(CodeDescription),
            source: optional(string()),
            message: string(),
            tags: optional(list_of(DiagnosticTag)),
            related_information: optional(list_of(DiagnosticRelatedInformation)),
            data: optional(any())
  end

  defmodule TextEdit do
    use Proto
    deftype range: Range, new_text: string()
  end

  defmodule FormattingOptions do
    use Proto

    deftype tab_size: integer(),
            insert_spaces: boolean(),
            trim_trailing_whitespace: optional(boolean()),
            insert_final_newline: optional(boolean()),
            trim_final_newlines: optional(boolean()),
            ..: map_of(one_of([string(), boolean(), integer()]), as: :opts)
  end

  defmodule FileChangeType do
    use Proto

    defenum created: 1, changed: 2, deleted: 3
  end

  defmodule FileEvent do
    use Proto

    deftype uri: uri(), type: FileChangeType
  end

  defmodule ReferencesContext do
    use Proto

    deftype include_declaration: boolean()
  end

  defmodule FileOperationsCapabilities do
    use Proto

    deftype dynamic_registration: optional(boolean()),
            did_create: optional(boolean()),
            will_create: optional(boolean()),
            did_rename: optional(boolean()),
            will_rename: optional(boolean()),
            did_delete: optional(boolean()),
            will_delete: optional(boolean())
  end

  defmodule ResourceOperationKind do
    use Proto

    defenum create: "create", rename: "rename", delete: "delete"
  end

  defmodule FailureHandlingKind do
    use Proto

    defenum abort: "abort",
            trasactional: "transactional",
            text_only_transactional: "textOnlyTransactional",
            unto: "undo"
  end

  defmodule WorkspaceEdit.ClientCapabilities do
    use Proto

    deftype document_changes: optional(boolean()),
            resource_operations: optional(list_of(ResourceOperationKind))
  end

  defmodule DidChangeConfiguration.ClientCapabilities do
    use Proto

    deftype dynamic_registration: optional(boolean())
  end

  defmodule DidChangeWatchedFiles.ClientCapabilities do
    use Proto

    deftype dynamic_registration: optional(boolean()),
            relative_pattern_support: optional(boolean())
  end

  defmodule SymbolKind do
    use Proto

    defenum file: 1,
            module: 2,
            namespace: 3,
            package: 4,
            class: 5,
            method: 6,
            property: 7,
            field: 8,
            constructor: 9,
            enum: 10,
            interface: 11,
            function: 12,
            variable: 13,
            constant: 14,
            string: 15,
            number: 16,
            boolean: 17,
            array: 18,
            object: 19,
            key: 20,
            null: 21,
            enum_member: 22,
            struct: 23,
            event: 24,
            operator: 25,
            typep_arameter: 26
  end

  defmodule CompletionItemKind do
    use Proto

    defenum text: 1,
            method: 2,
            function: 3,
            constructor: 4,
            field: 5,
            variable: 6,
            class: 7,
            interface: 8,
            module: 9,
            property: 10,
            unit: 11,
            value: 12,
            enum: 13,
            keyword: 14,
            snippet: 15,
            color: 16,
            File: 17,
            reference: 18,
            folder: 19,
            enum_member: 20,
            constant: 21,
            struct: 22,
            event: 23,
            operator: 24,
            type_parameter: 25
  end

  defmodule SymbolTag do
    use Proto

    defenum deprecated: 1
  end

  defmodule ResolveProperties do
    use Proto
    deftype properties: list_of(string())
  end

  defmodule WorkspaceSymbol.ClientCapabilities do
    use Proto

    deftype dynamic_registration: optional(boolean()),
            value_set: optional(list_of(SymbolKind)),
            tag_support: optional(list_of(SymbolTag)),
            resolve_support: optional(ResolveProperties)
  end

  defmodule ExecuteCommand.ClientCapabilities do
    use Proto
    deftype dynamic_registration: optional(boolean())
  end

  defmodule SemanticTokensWorkspace.ClientCapabilities do
    use Proto

    deftype refresh_support: optional(boolean())
  end

  defmodule CodeLensWorkspace.ClientCapabilities do
    use Proto

    deftype refresh_support: optional(boolean())
  end

  defmodule InlineValueWorkspace.ClientCapabilities do
    use Proto
    deftype refresh_support: optional(boolean())
  end

  defmodule InlayHintWorkspace.ClientCapabilities do
    use Proto
    deftype refresh_support: optional(boolean())
  end

  defmodule DiagnosticWorkspace.ClientCapabilities do
    use Proto
    deftype refresh_support: optional(boolean())
  end

  defmodule WorkspaceCapabilities do
    use Proto

    deftype apply_edit: optional(boolean()),
            workspace_edit: optional(WorkspaceEdit.ClientCapabilities),
            did_change_configuration: optional(DidChangeConfiguration.ClientCapabilities),
            did_change_watched_files: optional(DidChangeWatchedFiles.ClientCapabilities),
            symbol: optional(WorkspaceSymbol.ClientCapabilities),
            execute_command: optional(ExecuteCommand.ClientCapabilities),
            workspace_folders: optional(boolean()),
            configuration: optional(boolean()),
            semantic_tokens: optional(SemanticTokensWorkspace.ClientCapabilities),
            code_lens: optional(CodeLensWorkspace.ClientCapabilities),
            file_operations: optional(FileOperationsCapabilities),
            inline_value: optional(InlineValueWorkspace.ClientCapabilities),
            inlay_hint: optional(InlayHintWorkspace.ClientCapabilities),
            diagnostic: optional(DiagnosticWorkspace.ClientCapabilities)
  end

  defmodule TextDocument.SyncKind do
    use Proto
    defenum none: 0, full: 1, incremental: 2
  end

  defmodule MarkupKind do
    use Proto
    defenum plain_text: "plaintext", markdown: "markdown"
  end

  defmodule CompletionItemTag do
    use Proto

    defenum deprecated: 1
  end

  defmodule InsertTextMode do
    use Proto

    defenum as_is: 1, adjust_indentation: 2
  end

  defmodule TagSupport do
    use Proto
    deftype value_set: list_of(CompletionItemTag)
  end

  defmodule ResolveSupport do
    use Proto

    deftype properties: list_of(string())
  end

  defmodule TextDocumentSync.ClientCapabilities do
    use Proto

    deftype dynamic_registration: optional(boolean()),
            will_save: optional(boolean()),
            will_save_wait_until: optional(boolean()),
            did_save: optional(boolean())
  end

  defmodule CompletionItem do
    defmodule InsertTextModeSupport do
      use Proto

      deftype value_set: list_of(InsertTextMode)
    end

    use Proto

    deftype snippet_support: optional(boolean()),
            commit_characters_support: optional(boolean()),
            documentation_format: optional(list_of(MarkupKind)),
            deprecated_support: optional(boolean()),
            preselect_support: optional(boolean()),
            tag_support: optional(TagSupport),
            insert_replace_support: optional(boolean()),
            resolve_support: optional(ResolveSupport),
            insert_text_mode_support: optional(InsertTextModeSupport),
            label_detail_support: optional(boolean())
  end

  defmodule Completion.ClientCapabilities do
    defmodule CompletionKindValues do
      use Proto

      deftype value_set: list_of(CompletionKind)
    end

    defmodule CompletionList do
      use Proto
      deftype item_defaults: optional(list_of(string()))
    end

    use Proto

    deftype dynamic_registration: optional(boolean()),
            completion_item: optional(CompletionItem),
            completion_item_kind: optional(CompletionKindValues),
            context_support: optional(boolean()),
            insert_text_mode: optional(InsertTextMode),
            completion_list: optional(CompletionList)
  end

  defmodule Hover.ClientCapabilities do
    use Proto

    deftype dynamic_registration: optional(boolean()),
            content_format: optional(list_of(MarkupKind))
  end

  defmodule SignatureHelp.ClientCapabilities do
    use Proto

    defmodule SignatureInformation do
      defmodule ParameterInformation do
        use Proto
        deftype label_offset_support: optional(boolean())
      end

      use Proto

      deftype documentation_format: optional(list_of(MarkupKind)),
              parameter_information: optional(ParameterInformation),
              active_parameter_support: optional(boolean())
    end

    deftype dynamic_registration: optional(boolean()),
            signature_information: optional(SignatureInformation),
            context_support: optional(boolean())
  end

  defmodule TextDocument.Capabilities do
    use Proto

    deftype syncronization: optional(TextDocumentSync.ClientCapabilities),
            completion: optional(Completion.ClientCapabilities),
            hover: optional(Hover.ClientCapabilities),
            signature_help: optional(SignatureHelp.ClientCapabilities)
  end

  defmodule GeneralCapabilities do
    use Proto
  end

  defmodule ClientCapabilities do
    use Proto

    deftype workspace: WorkspaceCapabilities,
            text_document: TextDocument.Capabilities,
            #            window: WindowCapabilities,
            general: optional(GeneralCapabilities)
  end

  defmodule InitializeParams do
    use Proto
    deftype root_uri: uri(), capabilities: map_of(any())
  end

  defmodule WorkspaceFolder do
    use Proto
    deftype uri: uri(), name: string()
  end
end
