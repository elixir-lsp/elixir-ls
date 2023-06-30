# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Hover.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype content_format: optional(list_of(Types.Markup.Kind)),
          dynamic_registration: optional(boolean())
end
