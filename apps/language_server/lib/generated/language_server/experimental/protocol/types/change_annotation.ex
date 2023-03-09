# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.ChangeAnnotation do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  use Proto

  deftype description: optional(string()),
          label: string(),
          needs_confirmation: optional(boolean())
end
