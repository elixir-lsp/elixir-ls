# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.PublishDiagnostics.Params do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto
  deftype diagnostics: list_of(Types.Diagnostic), uri: string(), version: optional(integer())
end
