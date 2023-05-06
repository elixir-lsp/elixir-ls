# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.CodeAction.Params do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype context: Types.CodeAction.Context,
          partial_result_token: optional(Types.Progress.Token),
          range: Types.Range,
          text_document: Types.TextDocument.Identifier,
          work_done_token: optional(Types.Progress.Token)
end
