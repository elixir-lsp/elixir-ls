# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Workspace.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype apply_edit: optional(boolean()),
          code_lens: optional(Types.CodeLens.Workspace.ClientCapabilities),
          configuration: optional(boolean()),
          diagnostics: optional(Types.Diagnostic.Workspace.ClientCapabilities),
          did_change_configuration: optional(Types.DidChangeConfiguration.ClientCapabilities),
          did_change_watched_files: optional(Types.DidChangeWatchedFiles.ClientCapabilities),
          execute_command: optional(Types.ExecuteCommand.ClientCapabilities),
          file_operations: optional(Types.FileOperation.ClientCapabilities),
          inlay_hint: optional(Types.InlayHintWorkspace.ClientCapabilities),
          inline_value: optional(Types.InlineValue.Workspace.ClientCapabilities),
          semantic_tokens: optional(Types.SemanticTokens.Workspace.ClientCapabilities),
          symbol: optional(Types.Workspace.Symbol.ClientCapabilities),
          workspace_edit: optional(Types.Workspace.Edit.ClientCapabilities),
          workspace_folders: optional(boolean())
end
