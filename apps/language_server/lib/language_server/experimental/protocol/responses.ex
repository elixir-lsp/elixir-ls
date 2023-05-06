defmodule LSP.Responses do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types

  defmodule FindReferences do
    use Proto

    defresponse optional(list_of(Types.Location))
  end

  defmodule GotoDefinition do
    use Proto

    defresponse optional(Types.Location)
  end

  defmodule Formatting do
    use Proto

    defresponse optional(list_of(Types.TextEdit))
  end

  defmodule CodeAction do
    use Proto

    defresponse optional(list_of(Types.CodeAction))
  end

  @type response :: FindReferences.t() | CodeAction.t() | Formatting.t()
end
