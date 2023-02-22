# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule Disabled do
    use Proto
    deftype reason: string()
  end

  use Proto

  deftype command: optional(Types.Command),
          data: optional(any()),
          diagnostics: optional(list_of(Types.Diagnostic)),
          disabled: optional(Disabled),
          edit: optional(Types.Workspace.Edit),
          is_preferred: optional(boolean()),
          kind: optional(Types.CodeAction.Kind),
          title: string()
end
