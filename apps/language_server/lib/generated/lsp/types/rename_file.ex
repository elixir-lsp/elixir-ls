# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.RenameFile do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype annotation_id: optional(Types.ChangeAnnotation.Identifier),
          kind: literal("rename"),
          new_uri: string(),
          old_uri: string(),
          options: optional(Types.RenameFile.Options)
end
