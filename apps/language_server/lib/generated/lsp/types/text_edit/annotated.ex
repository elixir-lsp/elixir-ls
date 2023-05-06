# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.TextEdit.Annotated do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto
  deftype annotation_id: Types.ChangeAnnotation.Identifier, new_text: string(), range: Types.Range
end
