# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Command do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  use Proto
  deftype arguments: optional(list_of(any())), command: string(), title: string()
end
