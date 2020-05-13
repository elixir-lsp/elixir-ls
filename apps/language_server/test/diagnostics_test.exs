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

      [diagnostic | _] =
        [build_diagnostic(message, file, position)]
        |> Diagnostics.normalize(root_path)

      assert diagnostic.message == """
             (CompileError) some message

                 Hint: Some hint

             Stacktrace:
               │ (elixir 1.10.1) lib/macro.ex:304: Macro.pipe/3
               │ (stdlib 3.7.1) lists.erl:1263: :lists.foldl/3
               │ (elixir 1.10.1) expanding macro: Kernel.|>/2
               │ expanding macro: SomeModule.sigil_L/2
               │ lib/my_app/my_module.ex:10: MyApp.MyModule.render/1\
             """
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
        |> Diagnostics.normalize(root_path)

      assert diagnostic.message == """
             (CompileError) some message

             Stacktrace:
               │ lib/my_app/my_module.ex:10: MyApp.MyModule.render/1\
             """

      assert diagnostic.position == 3
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
        |> Diagnostics.normalize(root_path)

      assert diagnostic.message =~ "(CompileError) some message"
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
        |> Diagnostics.normalize(root_path)

      assert diagnostic.message == """
             (CompileError) lib/non_existing.ex:3: some message

             Stacktrace:
               │ lib/my_app/my_module.ex:10: MyApp.MyModule.render/1\
             """

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
        |> Diagnostics.normalize(root_path)

      assert diagnostic.position == 13
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
