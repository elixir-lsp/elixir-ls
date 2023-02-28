# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit.Annotated do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto
  deftype annotation_id: Types.ChangeAnnotation.Identifier, new_text: string(), range: Types.Range
end
