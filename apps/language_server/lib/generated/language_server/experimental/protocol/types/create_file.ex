# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.CreateFile do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype annotation_id: optional(Types.ChangeAnnotation.Identifier),
          kind: literal("create"),
          options: optional(Types.CreateFile.Options),
          uri: string()
end
