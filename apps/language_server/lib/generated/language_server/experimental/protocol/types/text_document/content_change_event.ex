# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.TextDocument.ContentChangeEvent do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types

  defmodule TextDocumentContentChangeEvent do
    use Proto
    deftype range: Types.Range, range_length: optional(integer()), text: string()
  end

  defmodule TextDocumentContentChangeEvent1 do
    use Proto
    deftype text: string()
  end

  use Proto
  defalias one_of([TextDocumentContentChangeEvent, TextDocumentContentChangeEvent1])
end
