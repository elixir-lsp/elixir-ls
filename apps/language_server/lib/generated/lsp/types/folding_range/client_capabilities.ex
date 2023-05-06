# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.FoldingRange.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types

  defmodule FoldingRange do
    use Proto
    deftype collapsed_text: optional(boolean())
  end

  defmodule FoldingRangeKind do
    use Proto
    deftype value_set: optional(list_of(Types.FoldingRange.Kind))
  end

  use Proto

  deftype dynamic_registration: optional(boolean()),
          folding_range: optional(FoldingRange),
          folding_range_kind: optional(FoldingRangeKind),
          line_folding_only: optional(boolean()),
          range_limit: optional(integer())
end
