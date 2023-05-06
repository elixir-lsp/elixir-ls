# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.CreateFile do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype annotation_id: optional(Types.ChangeAnnotation.Identifier),
          kind: literal("create"),
          options: optional(Types.CreateFile.Options),
          uri: string()
end
