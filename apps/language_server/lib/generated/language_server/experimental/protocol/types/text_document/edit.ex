# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.TextDocument.Edit do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype edits: list_of(one_of([Types.TextEdit, Types.TextEdit.Annotated])),
          text_document: Types.TextDocument.OptionalVersioned.Identifier
end
