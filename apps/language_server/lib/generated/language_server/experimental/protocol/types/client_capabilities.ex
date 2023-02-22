# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype experimental: optional(any()),
          general: optional(Types.General.ClientCapabilities),
          notebook_document: optional(Types.Notebook.Document.ClientCapabilities),
          text_document: optional(Types.TextDocument.ClientCapabilities),
          window: optional(Types.Window.ClientCapabilities),
          workspace: optional(Types.Workspace.ClientCapabilities)
end
