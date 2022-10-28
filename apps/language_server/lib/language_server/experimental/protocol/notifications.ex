defmodule ElixirLS.LanguageServer.Experimental.Protocol.Notifications do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule Initialized do
    use Proto
    defnotification "initialized", :shared
  end

  defmodule Cancel do
    use Proto

    defnotification("$/cancelRequest", :shared, id: integer())
  end

  defmodule DidOpen do
    use Proto

    defnotification("textDocument/didOpen", :shared, text_document: Types.TextDocument)
  end

  defmodule DidClose do
    use Proto

    defnotification("textDocument/didClose", :shared, text_document: Types.TextDocument.Identifier)
  end

  defmodule DidChange do
    use Proto

    defnotification("textDocument/didChange", :shared,
      text_document: Types.TextDocument.VersionedIdentifier,
      content_changes: list_of(Types.TextDocument.ContentChangeEvent)
    )
  end

  defmodule DidChangeConfiguration do
    use Proto

    defnotification("workspace/didChangeConfiguration", :shared, settings: map_of(any()))
  end

  defmodule DidChangeWatchedFiles do
    use Proto

    defnotification("workspace/didChangeWatchedFiles", :shared, changes: list_of(Types.FileEvent))
  end

  defmodule DidSave do
    use Proto

    defnotification("textDocument/didSave", :shared, text_document: Types.TextDocument.Identifier)
  end

  use Proto, decoders: :notifications
end
