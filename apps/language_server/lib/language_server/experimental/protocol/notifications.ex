defmodule ElixirLS.LanguageServer.Experimental.Protocol.Notifications do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule Cancel do
    use Proto

    defnotification "$/cancelRequest", id: integer()
  end

  defmodule DidOpen do
    use Proto

    defnotification "textDocument/didOpen", text_document: Types.TextDocument
  end

  defmodule DidClose do
    use Proto

    defnotification "textDocument/didClose", text_document: Types.TextDocument.Identifier
  end

  defmodule DidChange do
    use Proto

    defnotification "textDocument/didChange",
      text_document: Types.TextDocument.VersionedIdentifier,
      content_changes: list_of(Types.TextDocument.ContentChangeEvent)
  end

  defmodule DidChangeConfiguration do
    use Proto

    defnotification "workspace/didChangeConfiguration", settings: map_of(any())
  end

  defmodule DidChangeWatchedFiles do
    use Proto

    defnotification "workspace/didChangeWatchedFiles", changes: list_of(Types.FileEvent)
  end

  defmodule DidSave do
    use Proto

    defnotification "textDocument/didSave", text_document: Types.TextDocument.Identifier
  end

  use Proto, decoders: :notifications
end
