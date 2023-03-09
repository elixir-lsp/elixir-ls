# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.Window.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  use Proto

  deftype show_document: optional(Types.ShowDocument.ClientCapabilities),
          show_message: optional(Types.ShowMessageRequest.ClientCapabilities),
          work_done_progress: optional(boolean())
end
