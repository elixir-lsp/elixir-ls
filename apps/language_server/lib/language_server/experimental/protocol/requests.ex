defmodule ElixirLS.LanguageServer.Experimental.Protocol.Requests do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule FindReferences do
    use Proto

    defrequest "textDocument/references",
      text_document: Types.TextDocument.Identifier,
      position: Types.Position
  end

  use Proto, decoders: :requests
end
