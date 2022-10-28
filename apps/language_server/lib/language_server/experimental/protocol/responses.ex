defmodule ElixirLS.LanguageServer.Experimental.Protocol.Responses do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule FindReferences do
    use Proto

    defresponse optional(list_of(Types.Location))
  end

  defmodule Formatting do
    use Proto

    defresponse optional(list_of(Types.TextEdit))
  end
end
