# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.PublishDiagnostics.Params do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto
  deftype diagnostics: list_of(Types.Diagnostic), uri: string(), version: optional(integer())
end
