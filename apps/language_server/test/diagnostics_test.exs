defmodule ElixirLS.LanguageServer.DiagnosticsTest do
  alias ElixirLS.LanguageServer.Diagnostics
  use ExUnit.Case

  if Version.match?(System.version(), "< 1.16.0-dev") do
    describe "pre 1.16 Mix.Task.Compiler.Diagnostic normalization" do
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

        diagnostic =
          build_diagnostic(message, file, position)
          |> Diagnostics.from_mix_task_compiler_diagnostic(
            Path.join(root_path, "mix.exs"),
            root_path
          )

        assert diagnostic.position == 2
      end

      test "update file and position if file is present in the message" do
        root_path = Path.join(__DIR__, "fixtures/build_errors")
        file = Path.join(root_path, "lib/has_error.ex")
        position = 2

        message = """
        ** (CompileError) lib/has_error.ex:3: some message
            lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
        """

        diagnostic =
          build_diagnostic(message, file, position)
          |> Diagnostics.from_mix_task_compiler_diagnostic(
            Path.join(root_path, "mix.exs"),
            root_path
          )

        assert diagnostic.position == 3
      end

      test "update file and position with column if file is present in the message" do
        root_path = Path.join(__DIR__, "fixtures/build_errors")
        file = Path.join(root_path, "lib/has_error.ex")
        position = 2

        message = """
        ** (CompileError) lib/has_error.ex:3:5: some message
            lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
        """

        diagnostic =
          build_diagnostic(message, file, position)
          |> Diagnostics.from_mix_task_compiler_diagnostic(
            Path.join(root_path, "mix.exs"),
            root_path
          )

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

        diagnostic =
          build_diagnostic(message, file, position)
          |> Diagnostics.from_mix_task_compiler_diagnostic(
            Path.join(root_path, "mix.exs"),
            root_path
          )

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

        diagnostic =
          build_diagnostic(message, file, position)
          |> Diagnostics.from_mix_task_compiler_diagnostic(
            Path.join(root_path, "mix.exs"),
            root_path
          )

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

        diagnostic =
          build_diagnostic(message, file, position)
          |> Diagnostics.from_mix_task_compiler_diagnostic(
            Path.join(root_path, "mix.exs"),
            root_path
          )

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

  describe "normalization" do
    if Version.match?(System.version(), ">= 1.16.0-dev") do
      test "Mix.Task.Compiler.Diagnostic" do
        diagnostic = %Mix.Task.Compiler.Diagnostic{
          file: "/somedir/lib/b.ex",
          severity: :warning,
          message:
            "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
          position: {20, 5},
          compiler_name: "Elixir",
          span: nil,
          details: nil,
          stacktrace: [{Sample, :bar, 0, [file: "lib/b.ex", column: 5, line: 20]}]
        }

        normalized =
          Diagnostics.from_mix_task_compiler_diagnostic(
            diagnostic,
            "/somedir/mix.exs",
            "/somedir"
          )

        assert normalized == %Diagnostics{
                 file: "/somedir/lib/b.ex",
                 severity: :warning,
                 message:
                   "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
                 position: {20, 5},
                 compiler_name: "Elixir",
                 span: nil,
                 details: nil,
                 stacktrace: [{Sample, :bar, 0, [file: "lib/b.ex", column: 5, line: 20]}]
               }
      end

      test "Mix.Task.Compiler.Diagnostic without position - get from stacktrace" do
        diagnostic = %Mix.Task.Compiler.Diagnostic{
          file: Path.join(File.cwd!(), "temp.ex"),
          severity: :warning,
          message:
            "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
          position: 0,
          compiler_name: "Elixir",
          span: nil,
          details: nil,
          stacktrace: [{Sample, :bar, 0, [file: "temp.ex", column: 5, line: 20]}]
        }

        File.touch("temp.ex")

        normalized =
          Diagnostics.from_mix_task_compiler_diagnostic(
            diagnostic,
            "/somedir/mix.exs",
            File.cwd!()
          )

        assert normalized == %Diagnostics{
                 file: Path.join(File.cwd!(), "temp.ex"),
                 severity: :warning,
                 message:
                   "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
                 position: 20,
                 compiler_name: "Elixir",
                 span: nil,
                 details: nil,
                 stacktrace: [{Sample, :bar, 0, [file: "temp.ex", column: 5, line: 20]}]
               }
      after
        File.rm_rf!("temp.ex")
      end

      test "Mix.Task.Compiler.Diagnostic without file and position - get from stacktrace" do
        diagnostic = %Mix.Task.Compiler.Diagnostic{
          file: nil,
          severity: :warning,
          message:
            "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
          position: 0,
          compiler_name: "Elixir",
          span: nil,
          details: nil,
          stacktrace: [{Sample, :bar, 0, [file: "temp.ex", column: 5, line: 20]}]
        }

        File.touch("temp.ex")

        normalized =
          Diagnostics.from_mix_task_compiler_diagnostic(
            diagnostic,
            "/somedir/mix.exs",
            File.cwd!()
          )

        assert normalized == %Diagnostics{
                 file: Path.join(File.cwd!(), "temp.ex"),
                 severity: :warning,
                 message:
                   "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
                 position: 20,
                 compiler_name: "Elixir",
                 span: nil,
                 details: nil,
                 stacktrace: [{Sample, :bar, 0, [file: "temp.ex", column: 5, line: 20]}]
               }
      after
        File.rm_rf!("temp.ex")
      end

      test "Mix.Task.Compiler.Diagnostic without file and position - when attempt to get it from stacktrace fails fall back to mix.exs" do
        diagnostic = %Mix.Task.Compiler.Diagnostic{
          file: nil,
          severity: :warning,
          message:
            "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
          position: 0,
          compiler_name: "Elixir",
          span: nil,
          details: nil,
          stacktrace: [{Sample, :bar, 0, [file: "lib/b.ex", column: 5, line: 20]}]
        }

        normalized =
          Diagnostics.from_mix_task_compiler_diagnostic(
            diagnostic,
            "/somedir/mix.exs",
            "/somedir"
          )

        assert normalized == %Diagnostics{
                 file: "/somedir/mix.exs",
                 severity: :warning,
                 message:
                   "module attribute @bar in code block has no effect as it is never returned (remove the attribute or assign it to _ to avoid warnings)",
                 position: 0,
                 compiler_name: "Elixir",
                 span: nil,
                 details: nil,
                 stacktrace: [{Sample, :bar, 0, [file: "lib/b.ex", column: 5, line: 20]}]
               }
      end
    end

    test "Code.diagnostic/1" do
      diagnostic = %{
        file: "/somedir/mix.exs",
        message:
          "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
        position: 102,
        severity: :warning,
        span: nil,
        stacktrace: [{Foo, :__MODULE__, 0, [file: "mix.exs", line: 102]}]
      }

      normalized = Diagnostics.from_code_diagnostic(diagnostic, "/somedir/mix.exs", "/somedir")

      assert normalized == %Diagnostics{
               compiler_name: "Elixir",
               details: nil,
               file: "/somedir/mix.exs",
               message:
                 "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
               position: 102,
               severity: :warning,
               span: nil,
               stacktrace: [{Foo, :__MODULE__, 0, [file: "mix.exs", line: 102]}]
             }
    end

    test "Code.diagnostic/1 without position - get from stacktrace" do
      diagnostic = %{
        file: Path.join(File.cwd!(), "temp.ex"),
        message:
          "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
        position: 0,
        severity: :warning,
        span: nil,
        stacktrace: [{Foo, :__MODULE__, 0, [file: "temp.ex", line: 102]}]
      }

      File.touch("temp.ex")
      normalized = Diagnostics.from_code_diagnostic(diagnostic, "/somedir/mix.exs", File.cwd!())

      assert normalized == %Diagnostics{
               file: Path.join(File.cwd!(), "temp.ex"),
               severity: :warning,
               message:
                 "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
               position: 102,
               compiler_name: "Elixir",
               span: nil,
               details: nil,
               stacktrace: [{Foo, :__MODULE__, 0, [file: "temp.ex", line: 102]}]
             }
    after
      File.rm_rf!("temp.ex")
    end

    test "Code.diagnostic/1 without file and position - get from stacktrace" do
      diagnostic = %{
        file: nil,
        message:
          "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
        position: 0,
        severity: :warning,
        span: nil,
        stacktrace: [{Foo, :__MODULE__, 0, [file: "temp.ex", line: 102]}]
      }

      File.touch("temp.ex")
      normalized = Diagnostics.from_code_diagnostic(diagnostic, "/somedir/mix.exs", File.cwd!())

      assert normalized == %Diagnostics{
               file: Path.join(File.cwd!(), "temp.ex"),
               severity: :warning,
               message:
                 "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
               position: 102,
               compiler_name: "Elixir",
               span: nil,
               details: nil,
               stacktrace: [{Foo, :__MODULE__, 0, [file: "temp.ex", line: 102]}]
             }
    after
      File.rm_rf!("temp.ex")
    end

    test "Code.diagnostic/1 without file and position - when attempt to get it from stacktrace fails fall back to provided file" do
      diagnostic = %{
        file: nil,
        message:
          "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
        position: 0,
        severity: :warning,
        span: nil,
        stacktrace: [{Foo, :__MODULE__, 0, [file: "mix.exs", line: 102]}]
      }

      normalized = Diagnostics.from_code_diagnostic(diagnostic, "/somedir/mix.exs", "/somedir")

      assert normalized == %Diagnostics{
               compiler_name: "Elixir",
               details: nil,
               file: "/somedir/mix.exs",
               message:
                 "redefining module Foo (current version loaded from .elixir_ls/build/test/lib/somedir/ebin/Elixir.Foo.beam)",
               position: 0,
               severity: :warning,
               span: nil,
               stacktrace: [{Foo, :__MODULE__, 0, [file: "mix.exs", line: 102]}]
             }
    end

    if Version.match?(System.version(), ">= 1.16.0-dev") do
      test "exception" do
        payload = %TokenMissingError{
          file: "/somedir/lib/b.ex",
          line: 3,
          column: 13,
          end_line: 39,
          end_column: 1,
          snippet:
            "# throw :foo\n# exit(:bar)\ndefmodule A do\n  def a() do\n    raise \"asd\"\n  # end\nend\n# A.a()\n# IO.warn(\"dfg\", __ENV__)\n# \"oops\"\n# :ok\n# asdfsf = 2\n# :ok\n# defmodule Sample do\n#   @foo 1\n#   @bar 1\n#   @foo\n\n#   def bar do\n#     @bar\n#     :ok\n#   end\n# end\n# exit({:shutdown, 1})\n# throw :asd\n# exit(:dupa)\n# IO.warn(\"asd\")\ndefmodule Foo do\n  @after_verify __MODULE__\n\n  def __after_verify__(_) do\n    # raise \"what\"\n    # throw :asd\n    # exit(:qw)\n    # exit({:shutdown, 1})\n    # IO.warn(\"asd\")\n  end\nend\n",
          opening_delimiter: :do,
          expected_delimiter: :end,
          description:
            "missing terminator: end\nhint: it looks like the \"do\" on line 3 does not have a matching \"end\""
        }

        normalized = Diagnostics.from_error(:error, payload, [], "/somedir/mix.exs", "/somedir")

        assert %ElixirLS.LanguageServer.Diagnostics{
                 file: "/somedir/mix.exs",
                 severity: :error,
                 position: {3, 13},
                 compiler_name: "Elixir",
                 span: {39, 1},
                 details: {:error, %TokenMissingError{}},
                 stacktrace: []
               } = normalized
      end

      test "exception without position - fall back to stacktrace" do
        payload = %CompileError{
          file: "/somedir/lib/b.ex",
          line: nil
        }

        normalized =
          Diagnostics.from_error(
            :error,
            payload,
            [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}],
            "/somedir/mix.exs",
            "/somedir"
          )

        assert %ElixirLS.LanguageServer.Diagnostics{
                 file: "/somedir/mix.exs",
                 severity: :error,
                 position: 99,
                 compiler_name: "Elixir",
                 span: nil,
                 details: {:error, %CompileError{}},
                 stacktrace: [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}]
               } = normalized
      end

      test "exception without file and position - fall back to stacktrace" do
        payload = %RuntimeError{message: "foo"}

        normalized =
          Diagnostics.from_error(
            :error,
            payload,
            [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}],
            "/somedir/mix.exs",
            "/somedir"
          )

        assert %ElixirLS.LanguageServer.Diagnostics{
                 file: "/somedir/mix.exs",
                 severity: :error,
                 position: 99,
                 compiler_name: "Elixir",
                 span: nil,
                 details: {:error, %RuntimeError{__exception__: true, message: "foo"}},
                 stacktrace: [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}]
               } = normalized
      end

      test "exception without file and position - when attempt to get it from stacktrace fails fall back to provided file" do
        payload = %RuntimeError{message: "foo"}

        normalized = Diagnostics.from_error(:error, payload, [], "/somedir/mix.exs", "/somedir")

        assert %ElixirLS.LanguageServer.Diagnostics{
                 file: "/somedir/mix.exs",
                 severity: :error,
                 position: 0,
                 compiler_name: "Elixir",
                 span: nil,
                 details: {:error, %RuntimeError{__exception__: true, message: "foo"}},
                 stacktrace: []
               } = normalized
      end
    end

    test "throw" do
      payload = :asd

      normalized =
        Diagnostics.from_error(
          :throw,
          payload,
          [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}],
          "/somedir/mix.exs",
          "/somedir"
        )

      assert %ElixirLS.LanguageServer.Diagnostics{
               compiler_name: "Elixir",
               details: {:throw, :asd},
               file: "/somedir/mix.exs",
               position: 99,
               severity: :error,
               span: nil,
               stacktrace: [
                 {:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}
               ],
               message: "** (throw) :asd"
             } = normalized
    end

    test "exit" do
      payload = :asd

      normalized =
        Diagnostics.from_error(
          :exit,
          payload,
          [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}],
          "/somedir/mix.exs",
          "/somedir"
        )

      assert %ElixirLS.LanguageServer.Diagnostics{
               compiler_name: "Elixir",
               details: {:exit, :asd},
               file: "/somedir/mix.exs",
               position: 99,
               severity: :error,
               span: nil,
               stacktrace: [
                 {:elixir_compiler_2, :__FILE__, 1, [file: ~c"mix.exs", line: 99]}
               ],
               message: "** (exit) :asd"
             } = normalized
    end

    test "shutdown reason" do
      payload = :asd

      normalized = Diagnostics.from_shutdown_reason(payload, "/somedir/mix.exs", "/somedir")

      assert %ElixirLS.LanguageServer.Diagnostics{
               compiler_name: "Elixir",
               details: {:exit, :asd},
               file: "/somedir/mix.exs",
               position: 0,
               severity: :error,
               span: nil,
               stacktrace: [],
               message: ":asd"
             } = normalized
    end

    test "shutdown reason with exception stacktrace" do
      payload =
        {%RuntimeError{message: "foo"},
         [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"temp.ex", line: 99]}]}

      File.touch("temp.ex")
      normalized = Diagnostics.from_shutdown_reason(payload, "/somedir/mix.exs", File.cwd!())

      assert %ElixirLS.LanguageServer.Diagnostics{
               compiler_name: "Elixir",
               details:
                 {:exit,
                  {%RuntimeError{message: "foo"},
                   [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"temp.ex", line: 99]}]}},
               file: file,
               position: 99,
               severity: :error,
               span: nil,
               stacktrace: [
                 {:elixir_compiler_2, :__FILE__, 1, [file: ~c"temp.ex", line: 99]}
               ],
               message:
                 "an exception was raised:\n    ** (RuntimeError) foo\n        temp.ex:99: (file)"
             } = normalized

      assert file == Path.join(File.cwd!(), "temp.ex")
    after
      File.rm_rf!("temp.ex")
    end

    test "shutdown reason with exception stacktrace - when attempt to get it from stacktrace fails fall back to provided file" do
      payload =
        {%RuntimeError{message: "foo"},
         [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"/abc/temp.ex", line: 99]}]}

      File.touch("temp.ex")
      normalized = Diagnostics.from_shutdown_reason(payload, "/somedir/mix.exs", File.cwd!())

      assert %ElixirLS.LanguageServer.Diagnostics{
               compiler_name: "Elixir",
               details:
                 {:exit,
                  {%RuntimeError{message: "foo"},
                   [{:elixir_compiler_2, :__FILE__, 1, [file: ~c"/abc/temp.ex", line: 99]}]}},
               file: file,
               position: 0,
               severity: :error,
               span: nil,
               stacktrace: [
                 {:elixir_compiler_2, :__FILE__, 1, [file: ~c"/abc/temp.ex", line: 99]}
               ],
               message:
                 "an exception was raised:\n    ** (RuntimeError) foo\n        /abc/temp.ex:99: (file)"
             } = normalized

      assert file == "/somedir/mix.exs"
    after
      File.rm_rf!("temp.ex")
    end

    test "Kernel.ParallelCompiler.compile/1 tuple" do
      payload =
        {"/somedir/mix.exs", 74,
         "** (RuntimeError) asd\n    mix.exs:74: (file)\n    (elixir 1.16.0-rc.1) lib/kernel/parallel_compiler.ex:429: anonymous fn/5 in Kernel.ParallelCompiler.spawn_workers/8\n"}

      normalized =
        Diagnostics.from_kernel_parallel_compiler_tuple(payload, :error, "/somedir/mix.exs")

      assert normalized == %Diagnostics{
               file: "/somedir/mix.exs",
               severity: :error,
               message:
                 "** (RuntimeError) asd\n    mix.exs:74: (file)\n    (elixir 1.16.0-rc.1) lib/kernel/parallel_compiler.ex:429: anonymous fn/5 in Kernel.ParallelCompiler.spawn_workers/8\n",
               position: 74,
               compiler_name: "Elixir",
               span: nil,
               details: nil,
               stacktrace: []
             }
    end
  end
end
