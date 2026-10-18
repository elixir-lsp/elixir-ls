defmodule ElixirLS.LanguageServer.ParserTest do
  # defines a stand-in for Phoenix.LiveView.TagEngine
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Parser
  alias ElixirLS.LanguageServer.Parser.Context
  alias ElixirLS.LanguageServer.SourceFile

  # Other (async: false) test modules register the LSP `Tracer` as a global compiler
  # tracer and may leave it behind after its ETS table is gone, so compile the
  # stand-in module without tracers (see inlay_hints_integration_test.exs).
  defp compile_string_no_tracers(source) do
    prev_tracers = Code.compiler_options()[:tracers] || []
    Code.put_compiler_option(:tracers, [])

    try do
      Code.compile_string(source)
    after
      Code.put_compiler_option(:tracers, prev_tracers)
    end
  end

  describe "heex template engine errors" do
    setup do
      if Code.ensure_loaded?(Phoenix.LiveView.TagEngine) do
        :ok
      else
        # simulate LiveView 1.2 raising for macro components when the caller
        # does not `use Phoenix.Component`
        compile_string_no_tracers("""
        defmodule Phoenix.LiveView.TagEngine do
          @behaviour EEx.Engine
          def init(_opts), do: %{}

          def handle_body(_state),
            do: raise(ArgumentError, "macro components are only supported in modules that `use Phoenix.Component`")

          def handle_begin(state), do: state
          def handle_end(state), do: state
          def handle_text(state, _meta, _text), do: state
          def handle_expr(state, _marker, _expr), do: state
        end
        """)

        on_exit(fn ->
          :code.purge(Phoenix.LiveView.TagEngine)
          :code.delete(Phoenix.LiveView.TagEngine)
        end)

        :ok
      end
    end

    test "non-syntax engine errors do not crash parsing" do
      if Code.ensure_loaded?(Phoenix.LiveView.TagEngine.Parser) do
        :ok
      else
        file = %Context{
          source_file: %SourceFile{
            text: "<div>hello</div>",
            version: 1,
            language_id: "phoenix-heex"
          },
          path: "/tmp/foo.html.heex"
        }

        assert %Context{flag: :not_parsable, diagnostics: []} = Parser.do_parse(file)
      end
    end
  end

  test "elixir syntax errors are reported as diagnostics" do
    file = %Context{
      source_file: %SourceFile{text: "foo(", version: 1, language_id: "elixir"},
      path: "/tmp/foo.ex"
    }

    assert %Context{diagnostics: [_ | _]} = Parser.do_parse(file)
  end
end
