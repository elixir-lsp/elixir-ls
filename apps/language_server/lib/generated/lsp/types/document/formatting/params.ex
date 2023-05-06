# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Document.Formatting.Params do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype options: Types.Formatting.Options,
          text_document: Types.TextDocument.Identifier,
          work_done_token: optional(Types.Progress.Token)
end
