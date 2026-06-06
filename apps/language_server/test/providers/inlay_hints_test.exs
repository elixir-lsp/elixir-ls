defmodule ElixirLS.LanguageServer.Providers.InlayHintsTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.InlayHints
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder

  defp run_hints(source, settings \\ %{}) do
    parser_context = ParserContextBuilder.from_string(source)
    range = SourceFile.full_range(parser_context.source_file)

    {:ok, hints} = InlayHints.inlay_hints(parser_context, range, settings: settings)
    hints
  end

  describe "variable hints" do
    test "returns integer label on simple binding" do
      source = """
      defmodule Sample do
        def run do
          value = 42
          :ok
        end
      end
      """

      hints = run_hints(source)

      assert Enum.any?(hints, &(&1.label == "integer"))
    end

    test "respects settings toggle" do
      source = """
      defmodule Sample do
        def run do
          value = 42
          :ok
        end
      end
      """

      settings = %{"inlayHints" => %{"variableTypes" => %{"enabled" => false}}}

      assert [] == run_hints(source, settings)
    end

    test "emits hints on binding line but not on reads" do
      source = """
      defmodule Inline do
        def foo do
          asd = %{foo: 123}
          asd
        end
      end
      """

      hints = run_hints(source)

      assert Enum.any?(hints, &(&1.position.line == 2))
      refute Enum.any?(hints, &(&1.position.line == 3))
    end
  end
end
