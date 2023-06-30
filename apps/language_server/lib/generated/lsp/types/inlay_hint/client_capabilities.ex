# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.InlayHint.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto

  defmodule ResolveSupport do
    use Proto
    deftype properties: list_of(string())
  end

  use Proto
  deftype dynamic_registration: optional(boolean()), resolve_support: optional(ResolveSupport)
end
