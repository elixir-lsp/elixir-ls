defmodule ElixirLS.LanguageServer.DiagnosticsTest do
  alias ElixirLS.LanguageServer.Diagnostics
  use ExUnit.Case

  describe "normalize/2" do
    test "extract the stacktrace from the message and format it" do
      root_path = Path.join(__DIR__, "fixtures/build_errors")
      file = Path.join(root_path, "lib/has_error.ex")
      position = 2

      message = """
      ** (CompileError) some message

          Hint: Some hint
          (elixir 1.10.1) lib/macro.ex:304: Macro.pipe/3
          (stdlib 3.7.1) lists.erl:1263: :lists.foldl/3
          (elixir 1.10.1) expanding macro: Kernel.|>/2
          expanding macro: SomeModule.sigil_L/2
          lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
      """

      [_diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))
    end

    test "update file and position if file is present in the message" do
      root_path = Path.join(__DIR__, "fixtures/build_errors")
      file = Path.join(root_path, "lib/has_error.ex")
      position = 2

      message = """
      ** (CompileError) lib/has_error.ex:3: some message
          lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.position == 3
    end

    test "update file and position if file is present in the message - 1.16 format" do
      root_path = Path.join(__DIR__, "fixtures/build_errors_on_external_resource")
      file = Path.join(root_path, "lib/has_error.ex")
      position = 2

      message = """
      ** (SyntaxError) invalid syntax found on lib/template.eex:2:5:
        error: syntax error before: ','
        │
      2 │  , 
        │     ^
        │
        └─ lib/template.eex:2:5
        (eex 1.16.0-rc.0) lib/eex/compiler.ex:332: EEx.Compiler.generate_buffer/4
        lib/has_error.ex:2: (module)
        (elixir 1.16.0-rc.0) lib/kernel/parallel_compiler.ex:428: anonymous fn/5 in Kernel.ParallelCompiler.spawn_workers/8
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.position == {2, 5}
      assert diagnostic.file == Path.join(root_path, "lib/template.eex")
    end

    test "update file and position with column if file is present in the message" do
      root_path = Path.join(__DIR__, "fixtures/build_errors")
      file = Path.join(root_path, "lib/has_error.ex")
      position = 2

      message = """
      ** (CompileError) lib/has_error.ex:3:5: some message
          lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.position == {3, 5}
    end

    test "update file and position if file is present in the message (umbrella)" do
      root_path = Path.join(__DIR__, "fixtures/umbrella")
      file = Path.join(root_path, "lib/file_to_be_replaced.ex")
      position = 3

      message = """
      ** (CompileError) lib/app2.ex:5: some message
          (elixir 1.10.1) lib/macro.ex:304: Macro.pipe/3
          lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.file =~ "umbrella/apps/app2/lib/app2.ex"
      assert diagnostic.position == 5
    end

    test "don't update file nor position if file in message does not exist" do
      root_path = Path.join(__DIR__, "fixtures/build_errors_on_external_resource")
      file = Path.join(root_path, "lib/has_error.ex")
      position = 2

      message = """
      ** (CompileError) lib/non_existing.ex:3: some message
          lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.position == 2
    end

    test "if position is nil, try to retrieve it info from the stacktrace" do
      root_path = Path.join(__DIR__, "fixtures/build_errors")
      file = Path.join(root_path, "lib/demo_web/router.ex")
      position = nil

      message = """
      ** (FunctionClauseError) no function clause matching in Phoenix.Router.Scope.pipeline/2

      The following arguments were given to Phoenix.Router.Scope.pipeline/2:

          # 1
          DemoWeb.Router

          # 2
          "api"

          (phoenix 1.5.1) lib/phoenix/router/scope.ex:66: Phoenix.Router.Scope.pipeline/2
          lib/demo_web/router.ex:13: (module)
          (stdlib 3.7.1) erl_eval.erl:680: :erl_eval.do_apply/6
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.position == 13
    end

    test "if position is nil and error is TokenMissingError, try to retrieve from the hint" do
      root_path = Path.join(__DIR__, "fixtures/token_missing_error")
      file = Path.join(root_path, "lib/has_error.ex")
      position = nil

      message = """
      ** (TokenMissingError) lib/has_error.ex:16:1: missing terminator: end (for "do" starting at line 1)

          HINT: it looks like the "do" on line 6 does not have a matching "end"

          (elixir 1.12.1) lib/kernel/parallel_compiler.ex:319: anonymous fn/4 in Kernel.ParallelCompiler.spawn_workers/7
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.position == 1
    end

    test "if position is nil and error is TokenMissingError, try to retrieve from the hint - 1.16 format" do
      root_path = Path.join(__DIR__, "fixtures/token_missing_error")
      file = Path.join(root_path, "lib/has_error.ex")
      position = nil

      message = """
      ** (TokenMissingError) token missing on lib/has_error.ex:16:1:
      error: missing terminator: end (for "fn" starting at line 6)
      └─ lib/has_error.ex:16:1
      """

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path, Path.join(root_path, "mix.exs"))

      assert diagnostic.position == 6
    end

    defp build_diagnostic(message, file, position) do
      %Mix.Task.Compiler.Diagnostic{
        compiler_name: "Elixir",
        details: nil,
        file: file,
        message: message,
        position: position,
        severity: :error
      }
    end
  end
end
