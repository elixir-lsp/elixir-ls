# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.Document.Formatting.Params do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype options: Types.Formatting.Options,
          text_document: Types.TextDocument.Identifier,
          work_done_token: optional(Types.Progress.Token)
end
