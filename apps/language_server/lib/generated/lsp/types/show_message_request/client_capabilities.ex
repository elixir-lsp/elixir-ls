# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.ShowMessageRequest.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto

  defmodule MessageActionItem do
    use Proto
    deftype additional_properties_support: optional(boolean())
  end

  use Proto
  deftype message_action_item: optional(MessageActionItem)
end
