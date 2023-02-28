# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule CodeActionKind do
    use Proto
    deftype value_set: list_of(Types.CodeAction.Kind)
  end

  defmodule CodeActionLiteralSupport do
    use Proto
    deftype code_action_kind: CodeActionKind
  end

  defmodule ResolveSupport do
    use Proto
    deftype properties: list_of(string())
  end

  use Proto

  deftype code_action_literal_support: optional(CodeActionLiteralSupport),
          data_support: optional(boolean()),
          disabled_support: optional(boolean()),
          dynamic_registration: optional(boolean()),
          honors_change_annotations: optional(boolean()),
          is_preferred_support: optional(boolean()),
          resolve_support: optional(ResolveSupport)
end
