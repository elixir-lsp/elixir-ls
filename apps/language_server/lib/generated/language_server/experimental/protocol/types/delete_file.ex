# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.DeleteFile do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype annotation_id: optional(Types.ChangeAnnotation.Identifier),
          kind: literal("delete"),
          options: optional(Types.DeleteFile.Options),
          uri: string()
end
