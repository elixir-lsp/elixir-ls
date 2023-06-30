# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.TextDocument.OptionalVersioned.Identifier do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  use Proto
  deftype uri: string(), version: one_of([integer(), nil])
end
