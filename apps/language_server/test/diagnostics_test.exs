defmodule ElixirLS.LanguageServer.DiagnosticsTest do
  alias ElixirLS.LanguageServer.Diagnostics
  use ExUnit.Case

  describe "normalization" do
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
