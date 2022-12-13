defmodule ElixirLS.LanguageServer.Experimental.Protocol.Responses do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule FindReferencesResponse do
    use Proto

    defresponse optional(list_of(Types.Location))
  end
end
