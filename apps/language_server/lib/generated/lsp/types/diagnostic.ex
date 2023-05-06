# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Diagnostic do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype code: optional(one_of([integer(), string()])),
          code_description: optional(Types.CodeDescription),
          data: optional(any()),
          message: string(),
          range: Types.Range,
          related_information: optional(list_of(Types.Diagnostic.RelatedInformation)),
          severity: optional(Types.Diagnostic.Severity),
          source: optional(string()),
          tags: optional(list_of(Types.Diagnostic.Tag))
end
