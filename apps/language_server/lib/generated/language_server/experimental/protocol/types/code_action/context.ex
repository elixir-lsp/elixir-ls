# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction.Context do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype diagnostics: list_of(Types.Diagnostic),
          only: optional(list_of(Types.CodeAction.Kind)),
          trigger_kind: optional(Types.CodeAction.Trigger.Kind)
end
