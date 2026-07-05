defmodule ElixirLS.LanguageServer.ClientCapabilitiesTest do
  # persistent_term-backed global state — must not interleave with tests that store capabilities
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.ClientCapabilities

  setup do
    previous = ClientCapabilities.get()

    on_exit(fn ->
      if previous, do: ClientCapabilities.store(previous)
    end)

    :ok
  end

  defp store_semantic_tokens_caps(augments) do
    ClientCapabilities.store(%GenLSP.Structures.ClientCapabilities{
      text_document: %GenLSP.Structures.TextDocumentClientCapabilities{
        semantic_tokens: %GenLSP.Structures.SemanticTokensClientCapabilities{
          requests: %{},
          token_types: [],
          token_modifiers: [],
          formats: [],
          augments_syntax_tokens: augments
        }
      }
    })
  end

  describe "semantic_tokens_augments_syntax_tokens?/0" do
    test "true when the client augments syntax tokens" do
      store_semantic_tokens_caps(true)
      assert ClientCapabilities.semantic_tokens_augments_syntax_tokens?()
    end

    test "true when the capability is not stated (optional field defaults)" do
      store_semantic_tokens_caps(nil)
      assert ClientCapabilities.semantic_tokens_augments_syntax_tokens?()

      ClientCapabilities.store(%GenLSP.Structures.ClientCapabilities{})
      assert ClientCapabilities.semantic_tokens_augments_syntax_tokens?()
    end

    test "false only when the client explicitly replaces syntax coloring" do
      store_semantic_tokens_caps(false)
      refute ClientCapabilities.semantic_tokens_augments_syntax_tokens?()
    end
  end
end
