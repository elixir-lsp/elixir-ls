# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Formatting.Options do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  use Proto

  deftype insert_final_newline: optional(boolean()),
          insert_spaces: boolean(),
          tab_size: integer(),
          trim_final_newlines: optional(boolean()),
          trim_trailing_whitespace: optional(boolean())
end
