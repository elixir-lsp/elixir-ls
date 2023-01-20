defmodule ElixirLS.LanguageServer.Experimental.Server.Configuration.Support do
  defstruct code_action_dynamic_registration?: false,
            hierarchical_document_symbols?: false,
            snippet?: false,
            deprecated?: false,
            tags?: false,
            signature_help?: false

  def new(client_capabilities) do
    dynamic_registration? =
      fetch_bool(client_capabilities, ~w(textDocument codeAction dynamicRegistration))

    hierarchical_symbols? =
      fetch_bool(
        client_capabilities,
        ~w(textDocument documentSymbol hierarchicalDocumentSymbolSupport)
      )

    snippet? =
      fetch_bool(client_capabilities, ~w(textDocument completion completionItem snippetSupport))

    deprecated? =
      fetch_bool(
        client_capabilities,
        ~w(textDocument completion completionItem deprecatedSupport)
      )

    tags? = fetch_bool(client_capabilities, ~w(textDocument completion completionItem tagSupport))

    signature_help? = fetch_bool(client_capabilities, ~w(textDocument signatureHelp))

    %__MODULE__{
      code_action_dynamic_registration?: dynamic_registration?,
      hierarchical_document_symbols?: hierarchical_symbols?,
      snippet?: snippet?,
      deprecated?: deprecated?,
      tags?: tags?,
      signature_help?: signature_help?
    }
  end

  def fetch_bool(client_capabilities, path) do
    case get_in(client_capabilities, path) do
      nil -> false
      false -> false
      _ -> true
    end
  end
end
