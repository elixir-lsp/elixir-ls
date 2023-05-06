# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Markdown.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  use Proto
  deftype allowed_tags: optional(list_of(string())), parser: string(), version: optional(string())
end
