# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.References.LocatorTest do
  use ExUnit.Case, async: true
  # TODO remove
  alias ElixirSense.Core.References.Tracer
  # TODO remove
  alias ElixirSense.Core.Source
  alias ElixirLS.LanguageServer.Providers.References.Locator

  setup_all do
    {:ok, _} = Tracer.start_link()

    Code.compiler_options(
      tracers: [Tracer],
      ignore_module_conflict: true,
      parser_options: [columns: true]
    )

    Code.compile_file("./test/support/modules_with_references.ex")
    Code.compile_file("./test/support/module_with_builtin_type_shadowing.ex")
    Code.compile_file("./test/support/subscriber.ex")
    Code.compile_file("./test/support/functions_with_default_args.ex")

    trace = Tracer.get()

    %{trace: trace}
  end

  test "finds reference to local function shadowing builtin type", %{trace: trace} do
    buffer = """
    defmodule B.Callee do
      def fun() do
        #  ^
        :ok
      end
      def my_fun() do
        :ok
      end
    end
    """

    references = Locator.references(buffer, 2, 8, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/module_with_builtin_type_shadowing.ex"
             }
           ] = references

    assert range_1 == %{start: %{column: 14, line: 4}, end: %{column: 17, line: 4}} |> maybe_shift
  end

  test "find references with cursor over a function call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee1.func()
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{range: %{end: %{column: 62, line: 3}, start: %{column: 58, line: 3}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}} |> maybe_shift

    assert range_3 ==
             %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}} |> maybe_shift
  end

  test "find references with cursor over a function definition", %{trace: trace} do
    buffer = """
    defmodule ElixirSense.Providers.ReferencesTest.Modules.Callee1 do
      def func() do
        #    ^
        IO.puts ""
      end
      def func(par1) do
        #    ^
        IO.puts par1
      end
    end
    """

    references = Locator.references(buffer, 2, 10, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}} |> maybe_shift

    assert range_3 ==
             %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}} |> maybe_shift

    references = Locator.references(buffer, 6, 10, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}} |> maybe_shift
  end

  test "find references with cursor over a function definition with default arg", %{trace: trace} do
    buffer = """
    defmodule ElixirSenseExample.Subscription do
      def check(resource, models, user, opts \\\\ []) do
        IO.inspect({resource, models, user, opts})
      end
    end
    """

    references = Locator.references(buffer, 2, 10, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/subscriber.ex"
             },
             %{
               range: range_2,
               uri: "test/support/subscriber.ex"
             }
           ] = references

    assert range_1 == %{end: %{column: 42, line: 3}, start: %{column: 37, line: 3}} |> maybe_shift
    assert range_2 == %{end: %{column: 42, line: 4}, start: %{column: 37, line: 4}} |> maybe_shift
  end

  test "find references with cursor over a function with arity 1", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee1.func("test")
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{range: %{end: %{column: 62, line: 3}, start: %{column: 58, line: 3}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}} |> maybe_shift
  end

  test "find references with cursor over a function called via @attr.call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      @attr ElixirSense.Providers.ReferencesTest.Modules.Callee1
      def func() do
        @attr.func("test")
        #      ^
      end
    end
    """

    references = Locator.references(buffer, 4, 12, trace)

    assert [
             %{range: %{end: %{column: 15, line: 4}, start: %{column: 11, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}} |> maybe_shift
  end

  # TODO attributes not supported yet
  # test "find references with cursor over a function called via @attr.Submodule.call", %{trace: trace} do
  #   buffer = """
  #   defmodule Caller do
  #     @attr ElixirSense.Providers.ReferencesTest.Modules
  #     def func() do
  #       @attr.Callee1.func("test")
  #       #              ^
  #     end
  #   end
  #   """

  #   references = Locator.references(buffer, 4, 20, trace)

  #   assert [
  #            %{range: %{end: %{column: 15, line: 4}, start: %{column: 11, line: 4}}, uri: nil},
  #            %{
  #              uri: "test/support/modules_with_references.ex",
  #              range: range_1
  #            },
  #            %{
  #              uri: "test/support/modules_with_references.ex",
  #              range: range_2
  #            }
  #          ] = references

  #   assert range_1 == %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}}
  #   assert range_2 == %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}}
  # end

  test "find references to function called via @attr.call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee7.func_noarg()
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{
               range: %{end: %{column: 68, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 ==
             %{end: %{column: 23, line: 114}, start: %{column: 13, line: 114}} |> maybe_shift
  end

  test "find references with cursor over a function with arity 1 called via pipe operator", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def func() do
        "test"
        |> ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_arg()
        #                                                        ^
      end
    end
    """

    references = Locator.references(buffer, 4, 62, trace)

    assert [
             %{
               range: %{end: %{column: 69, line: 4}, start: %{column: 61, line: 4}},
               uri: nil
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 49, column: 63}, end: %{line: 49, column: 71}} |> maybe_shift
  end

  test "find references with cursor over a function with arity 1 captured", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        Task.start(&ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_arg/1)
        #                                                                  ^
      end
    end
    """

    references = Locator.references(buffer, 3, 72, trace)

    assert [
             %{
               range: %{end: %{column: 78, line: 3}, start: %{column: 70, line: 3}},
               uri: nil
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 49, column: 63}, end: %{line: 49, column: 71}} |> maybe_shift
  end

  test "find references with cursor over a function when caller uses pipe operator", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_arg("test")
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{
               range: %{end: %{column: 66, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 49, column: 63}, end: %{line: 49, column: 71}} |> maybe_shift
  end

  test "find references with cursor over a function when caller uses capture operator", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_no_arg()
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{
               range: %{end: %{column: 69, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range
             }
           ] = references

    if Version.match?(System.version(), ">= 1.14.0-rc.0") do
      # before 1.14 tracer reports invalid positions for captures
      # https://github.com/elixir-lang/elixir/issues/12023
      assert range == %{start: %{line: 55, column: 72}, end: %{line: 55, column: 83}}
    end
  end

  test "find references with cursor over a function with default argument when caller uses default arguments",
       %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg()
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg("test")
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{
               range: %{end: %{column: 66, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{range: %{end: %{column: 66, line: 4}, start: %{column: 58, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 90, column: 60}, end: %{line: 90, column: 68}} |> maybe_shift

    references = Locator.references(buffer, 4, 59, trace)

    assert [
             %{
               range: %{end: %{column: 66, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{range: %{end: %{column: 66, line: 4}, start: %{column: 58, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 90, column: 60}, end: %{line: 90, column: 68}} |> maybe_shift
  end

  test "find references with cursor over a function with default argument when caller does not uses default arguments",
       %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg1("test")
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg1()
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{
               range: %{end: %{column: 67, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{range: %{end: %{column: 67, line: 4}, start: %{column: 58, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 91, column: 60}, end: %{line: 91, column: 69}} |> maybe_shift

    references = Locator.references(buffer, 4, 59, trace)

    assert [
             %{
               range: %{end: %{column: 67, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{range: %{end: %{column: 67, line: 4}, start: %{column: 58, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 91, column: 60}, end: %{line: 91, column: 69}} |> maybe_shift
  end

  test "find references with cursor over a module with funs with default argument", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg1("test")
        #                                                 ^
      end
    end
    """

    references = Locator.references(buffer, 3, 55, trace)

    assert [
             %{range: %{end: %{column: 67, line: 3}, start: %{column: 58, line: 3}}, uri: nil},
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             },
             %{
               range: range_2,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 ==
             %{end: %{column: 68, line: 90}, start: %{column: 60, line: 90}} |> maybe_shift

    assert range_2 ==
             %{end: %{column: 69, line: 91}, start: %{column: 60, line: 91}} |> maybe_shift
  end

  test "find references for the correct arity version", %{trace: trace} do
    buffer = """
    defmodule Caller do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def func() do
        F.my_func(1)
        F.my_func(1, "")
        F.my_func()
        F.my_func(1, 2, 3)
      end
    end
    """

    references = Locator.references(buffer, 4, 8, trace)

    assert [
             %{
               range: %{end: %{column: 14, line: 4}, start: %{column: 7, line: 4}},
               uri: nil
             },
             %{
               range: %{end: %{column: 14, line: 5}, start: %{column: 7, line: 5}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/functions_with_default_args.ex"
             },
             %{
               range: range_2,
               uri: "test/support/functions_with_default_args.ex"
             }
           ] = references

    assert read_line("test/support/functions_with_default_args.ex", range_1) =~ "my_func(1)"

    assert read_line("test/support/functions_with_default_args.ex", range_2) =~
             "my_func(1, \"a\")"

    references = Locator.references(buffer, 5, 8, trace)

    assert [
             %{
               range: %{end: %{column: 14, line: 4}, start: %{column: 7, line: 4}},
               uri: nil
             },
             %{
               range: %{end: %{column: 14, line: 5}, start: %{column: 7, line: 5}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/functions_with_default_args.ex"
             },
             %{
               range: range_2,
               uri: "test/support/functions_with_default_args.ex"
             }
           ] = references

    assert read_line("test/support/functions_with_default_args.ex", range_1) =~ "my_func(1)"

    assert read_line("test/support/functions_with_default_args.ex", range_2) =~
             "my_func(1, \"a\")"
  end

  test "find references for the correct arity version in incomplete code", %{trace: trace} do
    buffer = """
    defmodule Caller do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def func() do
        F.my_func(
      end
    end
    """

    references = Locator.references(buffer, 4, 8, trace)

    assert [
             %{
               range: %{end: %{column: 14, line: 4}, start: %{column: 7, line: 4}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/functions_with_default_args.ex"
             },
             %{
               range: range_2
             },
             %{
               range: range_3
             },
             %{
               range: range_4
             }
           ] = references

    assert read_line("test/support/functions_with_default_args.ex", range_1) =~ "my_func()"
    assert read_line("test/support/functions_with_default_args.ex", range_2) =~ "my_func(1)"

    assert read_line("test/support/functions_with_default_args.ex", range_3) =~
             "my_func(1, \"a\")"

    assert read_line("test/support/functions_with_default_args.ex", range_4) =~ "my_func(1, 2, 3)"

    buffer = """
    defmodule Caller do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def func() do
        F.my_func(1
      end
    end
    """

    references = Locator.references(buffer, 4, 8, trace)

    assert [
             %{
               range: %{end: %{column: 14, line: 4}, start: %{column: 7, line: 4}},
               uri: nil
             },
             %{
               range: range_2,
               uri: "test/support/functions_with_default_args.ex"
             },
             %{
               range: range_3
             },
             %{
               range: range_4
             }
           ] = references

    assert read_line("test/support/functions_with_default_args.ex", range_2) =~ "my_func(1)"

    assert read_line("test/support/functions_with_default_args.ex", range_3) =~
             "my_func(1, \"a\")"

    assert read_line("test/support/functions_with_default_args.ex", range_4) =~ "my_func(1, 2, 3)"

    buffer = """
    defmodule Caller do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def func() do
        F.my_func(1, 2,
      end
    end
    """

    references = Locator.references(buffer, 4, 8, trace)

    assert [
             %{
               range: %{end: %{column: 14, line: 4}, start: %{column: 7, line: 4}},
               uri: nil
             },
             %{
               range: range_4,
               uri: "test/support/functions_with_default_args.ex"
             }
           ] = references

    assert read_line("test/support/functions_with_default_args.ex", range_4) =~ "my_func(1, 2, 3)"

    buffer = """
    defmodule Caller do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def func() do
        F.my_func(1, 2, 3,
      end
    end
    """

    references = Locator.references(buffer, 4, 8, trace)

    assert [] == references
  end

  test "find references for the correct arity version for metadata calls", %{trace: trace} do
    buffer = """
    defmodule SomeCallee do
      def my_func(), do: :ok
      def my_func(a, b \\\\ ""), do: :ok
      def my_func(1, 2, 3), do: :ok
    end

    defmodule Caller do
      alias SomeCallee, as: F
      def func() do
        F.my_func(1)
        F.my_func(1, "")
        F.my_func()
        F.my_func(1, 2, 3)
      end
    end
    """

    references = Locator.references(buffer, 3, 8, trace)

    assert [
             %{
               range: %{
                 end: %{column: 14, line: 10},
                 start: %{column: 7, line: 10}
               },
               uri: nil
             },
             %{
               range: %{
                 end: %{column: 14, line: 11},
                 start: %{column: 7, line: 11}
               },
               uri: nil
             }
           ] = references

    references = Locator.references(buffer, 10, 8, trace)

    assert [
             %{
               range: %{
                 end: %{column: 14, line: 10},
                 start: %{column: 7, line: 10}
               },
               uri: nil
             },
             %{
               range: %{
                 end: %{column: 14, line: 11},
                 start: %{column: 7, line: 11}
               },
               uri: nil
             }
           ] = references
  end

  test "does not find references for private remote calls in metadata", %{trace: trace} do
    buffer = """
    defmodule SomeCallee do
      defp my_func(), do: :ok
      defp my_func(a, b \\\\ ""), do: :ok
      defp my_func(1, 2, 3), do: :ok
    end

    defmodule Caller do
      alias SomeCallee, as: F
      def func() do
        F.my_func(1)
        F.my_func(1, "")
        F.my_func()
        F.my_func(1, 2, 3)
      end
    end
    """

    references = Locator.references(buffer, 3, 9, trace)

    assert [] == references

    references = Locator.references(buffer, 10, 8, trace)

    assert [] == references
  end

  if Version.match?(System.version(), ">= 1.15.0") do
  test "find references for metadata calls on variable or attribute",
       %{trace: trace} do
    buffer = """
    defmodule A do
      @callback abc() :: any()
    end

    defmodule B do
      @behaviour A

      def abc, do: :ok
    end

    defmodule X do
      @b B
      @b.abc()
      def a do
        b = B
        b.abc()
      end
    end
    """

    references = Locator.references(buffer, 8, 8, trace)

    assert [
             %{
               range: %{
                 end: %{column: 9, line: 13},
                 start: %{column: 6, line: 13}
               },
               uri: nil
             },
             %{
               range: %{
                 end: %{column: 10, line: 16},
                 start: %{column: 7, line: 16}
               },
               uri: nil
             }
           ] = references
  end
  end

  test "find references for the correct arity version for metadata calls with cursor over module",
       %{trace: trace} do
    buffer = """
    defmodule SomeCallee do
      def my_func(), do: :ok
      def my_func(a, b \\\\ ""), do: :ok
      def my_func(1, 2, 3), do: :ok
    end

    defmodule Caller do
      alias SomeCallee, as: F
      def func() do
        F.my_func(1)
        F.my_func(1, "")
        F.my_func()
        F.my_func(1, 2, 3)
      end
    end
    """

    references = Locator.references(buffer, 1, 13, trace)

    assert [
             %{
               range: %{
                 end: %{column: 14, line: 10},
                 start: %{column: 7, line: 10}
               },
               uri: nil
             },
             %{
               range: %{
                 end: %{column: 14, line: 11},
                 start: %{column: 7, line: 11}
               },
               uri: nil
             },
             %{range: %{end: %{column: 14, line: 12}, start: %{column: 7, line: 12}}, uri: nil},
             %{range: %{end: %{column: 14, line: 13}, start: %{column: 7, line: 13}}, uri: nil}
           ] = references

    references = Locator.references(buffer, 10, 8, trace)

    assert [
             %{
               range: %{
                 end: %{column: 14, line: 10},
                 start: %{column: 7, line: 10}
               },
               uri: nil
             },
             %{
               range: %{
                 end: %{column: 14, line: 11},
                 start: %{column: 7, line: 11}
               },
               uri: nil
             }
           ] = references
  end

  test "find references with cursor over a module with multi alias syntax", %{trace: trace} do
    buffer = """
    defmodule Caller do
      alias ElixirSense.Providers.ReferencesTest.Modules.Callee5
      alias ElixirSense.Providers.ReferencesTest.Modules.{Callee5}
    end
    """

    references_1 = Locator.references(buffer, 2, 57, trace)
    references_2 = Locator.references(buffer, 3, 58, trace)

    assert references_1 == references_2
    assert [_, _] = references_1
  end

  test "find references with cursor over a function call from an aliased module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def my() do
        alias ElixirSense.Providers.ReferencesTest.Modules.Callee1, as: C
        C.func()
        #  ^
      end
    end
    """

    references = Locator.references(buffer, 4, 8, trace)

    assert [
             %{range: %{end: %{column: 11, line: 4}, start: %{column: 7, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}} |> maybe_shift

    assert range_3 ==
             %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}} |> maybe_shift
  end

  test "find references with cursor over a function call from an imported module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def my() do
        import ElixirSense.Providers.ReferencesTest.Modules.Callee1
        func()
        #^
      end
    end
    """

    references = Locator.references(buffer, 4, 6, trace)

    assert [
             %{range: %{end: %{column: 9, line: 4}, start: %{column: 5, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}} |> maybe_shift

    assert range_3 ==
             %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}} |> maybe_shift
  end

  test "find references with cursor over a function call pipe from an imported module", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def my() do
        import ElixirSense.Providers.ReferencesTest.Modules.Callee1
        "" |> func
        #      ^
      end
    end
    """

    references = Locator.references(buffer, 4, 12, trace)

    assert [
             %{range: %{end: %{column: 15, line: 4}, start: %{column: 11, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}} |> maybe_shift
  end

  test "find references with cursor over a function capture from an imported module", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def my() do
        import ElixirSense.Providers.ReferencesTest.Modules.Callee1
        &func/0
        # ^
      end
    end
    """

    references = Locator.references(buffer, 4, 7, trace)

    assert [
             %{range: %{end: %{column: 10, line: 4}, start: %{column: 6, line: 4}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}} |> maybe_shift

    assert range_3 ==
             %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}} |> maybe_shift
  end

  test "find imported references", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee3.func()
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert references == [
             %{
               range: %{end: %{column: 62, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: %{start: %{line: 65, column: 47}, end: %{line: 65, column: 51}}
             },
             %{
               range: %{end: %{column: 13, line: 70}, start: %{column: 9, line: 70}},
               uri: "test/support/modules_with_references.ex"
             }
           ]
  end

  test "find references from remote calls with the function in the next line", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee3.func()
        #                                                     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 59, trace)

    assert [
             %{
               range: %{end: %{column: 62, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{
               range: %{end: %{column: 51, line: 65}, start: %{column: 47, line: 65}},
               uri: "test/support/modules_with_references.ex"
             },
             %{
               range: %{end: %{column: 13, line: 70}, start: %{column: 9, line: 70}},
               uri: "test/support/modules_with_references.ex"
             }
           ] = references
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "find references when module with __MODULE__ special form submodule function", %{
      trace: trace
    } do
      buffer = """
      defmodule ElixirSense.Providers.ReferencesTest.Modules do
        def func() do
          __MODULE__.Callee3.func()
          #                   ^
        end
      end
      """

      references = Locator.references(buffer, 3, 25, trace)

      assert references == [
               %{range: %{end: %{column: 28, line: 3}, start: %{column: 24, line: 3}}, uri: nil},
               %{
                 uri: "test/support/modules_with_references.ex",
                 range: %{start: %{line: 65, column: 47}, end: %{line: 65, column: 51}}
               },
               %{
                 range: %{end: %{column: 13, line: 70}, start: %{column: 9, line: 70}},
                 uri: "test/support/modules_with_references.ex"
               }
             ]
    end
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "find references when module with __MODULE__ special form submodule", %{trace: trace} do
      buffer = """
      defmodule MyLocalModule do
        defmodule Some do
          def func() do
            :ok
          end
        end
        __MODULE__.Some.func()
      end
      """

      references = Locator.references(buffer, 7, 15, trace)

      assert references == [
               %{range: %{start: %{column: 19, line: 7}, end: %{column: 23, line: 7}}, uri: nil}
             ]
    end
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "find references when module with __MODULE__ special form function", %{trace: trace} do
      buffer = """
      defmodule ElixirSense.Providers.ReferencesTest.Modules do
        def func() do
          __MODULE__.func()
          #            ^
        end
      end
      """

      references = Locator.references(buffer, 3, 18, trace)

      assert references == [
               %{
                 uri: nil,
                 range: %{
                   end: %{column: 20, line: 3},
                   start: %{column: 16, line: 3}
                 }
               }
             ]
    end
  end

  test "find references when module with __MODULE__ special form", %{trace: trace} do
    buffer = """
    defmodule MyLocalModule do
      def func() do
        __MODULE__.func()
        #    ^
      end
    end
    """

    references = Locator.references(buffer, 3, 10, trace)

    assert references == [
             %{
               uri: nil,
               range: %{
                 end: %{column: 20, line: 3},
                 start: %{column: 16, line: 3}
               }
             }
           ]
  end

  test "find references of variables", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def func do
        var1 = 1
        var2 = 2
        var1 = 3
        IO.puts(var1 + var2)
      end
      def func4(ppp) do

      end
    end
    """

    references = Locator.references(buffer, 6, 13, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 5, column: 5}, end: %{line: 5, column: 9}}},
             %{uri: nil, range: %{start: %{line: 6, column: 13}, end: %{line: 6, column: 17}}}
           ]

    references = Locator.references(buffer, 3, 6, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 9}}}
           ]
  end

  test "find references of variables outside module", %{trace: trace} do
    buffer = """
    bas = B
    bas.abc()
    """

    references = Locator.references(buffer, 1, 2, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 1, column: 1}, end: %{line: 1, column: 4}}},
             %{uri: nil, range: %{start: %{line: 2, column: 1}, end: %{line: 2, column: 4}}}
           ]
  end

  test "find reference for variable split across lines", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def func do
        var1 =
          1
        var1
      end
    end
    """

    references = Locator.references(buffer, 3, 6, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 9}}},
             %{uri: nil, range: %{start: %{line: 5, column: 5}, end: %{line: 5, column: 9}}}
           ]
  end

  test "find references of variables in arguments", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def call(conn) do
        if true do
          conn
        end
      end
    end
    """

    references = Locator.references(buffer, 2, 13, trace)

    assert references == [
             %{range: %{end: %{column: 16, line: 2}, start: %{column: 12, line: 2}}, uri: nil},
             %{range: %{end: %{column: 11, line: 4}, start: %{column: 7, line: 4}}, uri: nil}
           ]
  end

  test "find references for a redefined variable", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(var) do
        var = 1 + var

        var
      end
    end
    """

    # `var` defined in the function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 14}, end: %{line: 2, column: 17}}},
      %{uri: nil, range: %{start: %{line: 3, column: 15}, end: %{line: 3, column: 18}}}
    ]

    assert Locator.references(buffer, 2, 14, trace) == expected_references
    assert Locator.references(buffer, 3, 15, trace) == expected_references

    # `var` redefined in the function body
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 8}}},
      %{uri: nil, range: %{start: %{line: 5, column: 5}, end: %{line: 5, column: 8}}}
    ]

    assert Locator.references(buffer, 3, 5, trace) == expected_references
    assert Locator.references(buffer, 5, 5, trace) == expected_references
  end

  test "find references for a variable in a guard", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(var) when is_atom(var) do
        case var do
          var when var > 0 -> var
        end

        Enum.map([1, 2], fn x when x > 0 -> x end)
      end
    end
    """

    # `var` defined in the function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 14}, end: %{line: 2, column: 17}}},
      %{uri: nil, range: %{start: %{line: 2, column: 32}, end: %{line: 2, column: 35}}},
      %{uri: nil, range: %{start: %{line: 3, column: 10}, end: %{line: 3, column: 13}}}
    ]

    assert Locator.references(buffer, 2, 14, trace) == expected_references
    assert Locator.references(buffer, 2, 32, trace) == expected_references
    assert Locator.references(buffer, 3, 10, trace) == expected_references

    # `var` defined in the case clause
    expected_references = [
      %{uri: nil, range: %{start: %{line: 4, column: 7}, end: %{line: 4, column: 10}}},
      %{uri: nil, range: %{start: %{line: 4, column: 16}, end: %{line: 4, column: 19}}},
      %{uri: nil, range: %{start: %{line: 4, column: 27}, end: %{line: 4, column: 30}}}
    ]

    assert Locator.references(buffer, 4, 7, trace) == expected_references
    assert Locator.references(buffer, 4, 16, trace) == expected_references
    assert Locator.references(buffer, 4, 27, trace) == expected_references

    # `x`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 7, column: 25}, end: %{line: 7, column: 26}}},
      %{uri: nil, range: %{start: %{line: 7, column: 32}, end: %{line: 7, column: 33}}},
      %{uri: nil, range: %{start: %{line: 7, column: 41}, end: %{line: 7, column: 42}}}
    ]

    assert Locator.references(buffer, 7, 25, trace) == expected_references
    assert Locator.references(buffer, 7, 32, trace) == expected_references
    assert Locator.references(buffer, 7, 41, trace) == expected_references
  end

  test "find references for variable in inner scopes", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun([h | t]) do
        sum = h + my_fun(t)

        if h > sum do
          h + sum
        else
          h = my_fun(t) + sum
          h
        end
      end
    end
    """

    # `h` from the function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 15}, end: %{line: 2, column: 16}}},
      %{uri: nil, range: %{start: %{line: 3, column: 11}, end: %{line: 3, column: 12}}},
      %{uri: nil, range: %{start: %{line: 5, column: 8}, end: %{line: 5, column: 9}}},
      %{uri: nil, range: %{start: %{line: 6, column: 7}, end: %{line: 6, column: 8}}}
    ]

    Enum.each([{2, 15}, {3, 11}, {5, 8}, {6, 7}], fn {line, column} ->
      assert Locator.references(buffer, line, column, trace) == expected_references
    end)

    # `h` from the if-else scope
    expected_references = [
      %{uri: nil, range: %{start: %{line: 8, column: 7}, end: %{line: 8, column: 8}}},
      %{uri: nil, range: %{start: %{line: 9, column: 7}, end: %{line: 9, column: 8}}}
    ]

    assert Locator.references(buffer, 8, 7, trace) == expected_references
    assert Locator.references(buffer, 9, 7, trace) == expected_references

    # `sum`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 8}}},
      %{uri: nil, range: %{start: %{line: 5, column: 12}, end: %{line: 5, column: 15}}},
      %{uri: nil, range: %{start: %{line: 8, column: 23}, end: %{line: 8, column: 26}}},
      %{uri: nil, range: %{start: %{line: 6, column: 11}, end: %{line: 6, column: 14}}}
    ]

    Enum.each([{3, 5}, {5, 12}, {6, 11}, {8, 23}], fn {line, column} ->
      assert Locator.references(buffer, line, column, trace) == expected_references
    end)
  end

  test "find references for variable from the scope of an anonymous function", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(x, y) do
        x = Enum.map(x, fn x -> x + y end)
      end
    end
    """

    # `x` from the `my_fun` function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 14}, end: %{line: 2, column: 15}}},
      %{uri: nil, range: %{start: %{line: 3, column: 18}, end: %{line: 3, column: 19}}}
    ]

    assert Locator.references(buffer, 2, 14, trace) == expected_references
    assert Locator.references(buffer, 3, 18, trace) == expected_references

    # `y` from the `my_fun` function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 17}, end: %{line: 2, column: 18}}},
      %{uri: nil, range: %{start: %{line: 3, column: 33}, end: %{line: 3, column: 34}}}
    ]

    assert Locator.references(buffer, 2, 17, trace) == expected_references
    assert Locator.references(buffer, 3, 33, trace) == expected_references

    # `x` from the anonymous function
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 24}, end: %{line: 3, column: 25}}},
      %{uri: nil, range: %{start: %{line: 3, column: 29}, end: %{line: 3, column: 30}}}
    ]

    assert Locator.references(buffer, 3, 24, trace) == expected_references
    assert Locator.references(buffer, 3, 29, trace) == expected_references

    # redefined `x`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 6}}}
    ]

    assert Locator.references(buffer, 3, 5, trace) == expected_references
  end

  test "find references of a variable when using pin operator", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(a, b) do
        case a do
          ^b -> b
          %{b: ^b} = a -> b
        end
      end
    end
    """

    # `b`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 17}, end: %{line: 2, column: 18}}},
      %{uri: nil, range: %{start: %{line: 4, column: 8}, end: %{line: 4, column: 9}}},
      %{uri: nil, range: %{start: %{line: 4, column: 13}, end: %{line: 4, column: 14}}},
      %{uri: nil, range: %{start: %{line: 5, column: 13}, end: %{line: 5, column: 14}}},
      %{uri: nil, range: %{start: %{line: 5, column: 23}, end: %{line: 5, column: 24}}}
    ]

    assert Locator.references(buffer, 2, 17, trace) == expected_references
    assert Locator.references(buffer, 4, 8, trace) == expected_references
    assert Locator.references(buffer, 4, 13, trace) == expected_references
    assert Locator.references(buffer, 5, 13, trace) == expected_references
    assert Locator.references(buffer, 5, 23, trace) == expected_references

    # `a` redefined in a case clause
    expected_references = [
      %{uri: nil, range: %{start: %{line: 5, column: 18}, end: %{line: 5, column: 19}}}
    ]

    assert Locator.references(buffer, 5, 18, trace) == expected_references
  end

  test "find references of a variable in multiline struct", %{trace: trace} do
    buffer = """
    defmodule MyServer do
      def go do
        %Some{
          filed: my_var,
          other: some,
          other: my_var
        } = abc()
        fun(my_var, some)
      end
    end
    """

    # `my_var`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 4, column: 14}, end: %{line: 4, column: 20}}},
      %{uri: nil, range: %{start: %{line: 6, column: 14}, end: %{line: 6, column: 20}}},
      %{uri: nil, range: %{start: %{line: 8, column: 9}, end: %{line: 8, column: 15}}}
    ]

    assert Locator.references(buffer, 4, 15, trace) == expected_references
    assert Locator.references(buffer, 6, 15, trace) == expected_references
    assert Locator.references(buffer, 8, 10, trace) == expected_references
  end

  test "find references of a variable shadowing function", %{trace: trace} do
    buffer = """
    defmodule Vector do
      @spec magnitude(Vec2.t()) :: number()
      def magnitude(%Vec2{} = v), do: :math.sqrt(:math.pow(v.x, 2) + :math.pow(v.y, 2))

      @spec normalize(Vec2.t()) :: Vec2.t()
      def normalize(%Vec2{} = v) do
        length = magnitude(v)
        %{v | x: v.x / length, y: v.y / length}
      end
    end
    """

    # `my_var`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 7, column: 5}, end: %{line: 7, column: 11}}},
      %{uri: nil, range: %{start: %{line: 8, column: 20}, end: %{line: 8, column: 26}}},
      %{uri: nil, range: %{start: %{line: 8, column: 37}, end: %{line: 8, column: 43}}}
    ]

    assert Locator.references(buffer, 7, 6, trace) == expected_references
    assert Locator.references(buffer, 8, 21, trace) == expected_references
  end

  test "find references of write variable on definition", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def go() do
        abc = 5
        & [
          &1,
          abc,
          cde = 1,
          record_env()  
        ]
      end
    end
    """

    expected_references = [
      %{uri: nil, range: %{start: %{line: 7, column: 7}, end: %{line: 7, column: 10}}}
    ]

    assert Locator.references(buffer, 7, 8, trace) == expected_references
  end

  test "does not find references of write variable on read", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def go() do
        abc = 5
        & [
          &1,
          abc,
          cde = 1,
          record_env(cde)  
        ]
      end
    end
    """

    expected_references = [
      %{uri: nil, range: %{start: %{line: 7, column: 7}, end: %{line: 7, column: 10}}}
    ]

    # cde in cde = 1 is defined
    assert Locator.references(buffer, 7, 8, trace) == expected_references

    # cde in record_env(cde) is undefined
    assert Locator.references(buffer, 8, 19, trace) == []
  end

  test "find definition of write variable in match context", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def go(asd = 3, asd) do
        :ok
      end

      def go(asd = 3, [2, asd]) do
        :ok
      end
    end
    """

    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 10}, end: %{line: 2, column: 13}}},
      %{uri: nil, range: %{start: %{line: 2, column: 19}, end: %{line: 2, column: 22}}}
    ]

    assert Locator.references(buffer, 2, 11, trace) == expected_references

    assert Locator.references(buffer, 2, 20, trace) == expected_references

    expected_references = [
      %{uri: nil, range: %{start: %{line: 6, column: 10}, end: %{line: 6, column: 13}}},
      %{uri: nil, range: %{start: %{line: 6, column: 23}, end: %{line: 6, column: 26}}}
    ]

    assert Locator.references(buffer, 6, 24, trace) == expected_references
  end

  test "find references of attributes", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      @attr "abc"
      def fun do
        @attr
      end
    end
    """

    references = Locator.references(buffer, 4, 7, trace)

    assert references == [
             %{range: %{end: %{column: 8, line: 2}, start: %{column: 3, line: 2}}, uri: nil},
             %{range: %{end: %{column: 10, line: 4}, start: %{column: 5, line: 4}}, uri: nil}
           ]

    references = Locator.references(buffer, 2, 4, trace)

    assert references == [
             %{range: %{end: %{column: 8, line: 2}, start: %{column: 3, line: 2}}, uri: nil},
             %{range: %{end: %{column: 10, line: 4}, start: %{column: 5, line: 4}}, uri: nil}
           ]
  end

  test "find references of private functions from definition", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def calls_private do
        private_fun()
      end

      defp also_calls_private do
        private_fun()
      end

      defp private_fun do
        #     ^
        :ok
      end
    end
    """

    references = Locator.references(buffer, 10, 15, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 16}}},
             %{uri: nil, range: %{start: %{line: 7, column: 5}, end: %{line: 7, column: 16}}}
           ]
  end

  test "find references of private functions from invocation", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def calls_private do
        private_fun()
        #     ^
      end

      defp also_calls_private do
        private_fun()
      end

      defp private_fun do
        :ok
      end
    end
    """

    references = Locator.references(buffer, 3, 15, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 16}}},
             %{uri: nil, range: %{start: %{line: 8, column: 5}, end: %{line: 8, column: 16}}}
           ]
  end

  test "find references of public metadata functions from definition", %{trace: trace} do
    buffer = """
    defmodule MyCalleeModule.Some do
      def public_fun do
        #     ^
        :ok
      end
    end

    defmodule MyModule do
      def calls_public do
        MyCalleeModule.Some.public_fun()
      end

      defp also_calls_public do
        alias MyCalleeModule.Some
        Some.public_fun()
      end

      defp also_calls_public_import do
        import MyCalleeModule.Some
        public_fun()
      end
    end
    """

    references = Locator.references(buffer, 2, 15, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 10, column: 25}, end: %{line: 10, column: 35}}},
             %{uri: nil, range: %{start: %{line: 15, column: 10}, end: %{line: 15, column: 20}}},
             %{uri: nil, range: %{start: %{line: 20, column: 5}, end: %{line: 20, column: 15}}}
           ]
  end

  test "does not find references of private metadata functions from definition", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def calls_public do
        MyCalleeModule.Some.public_fun()
      end

      defp also_calls_public do
        alias MyCalleeModule.Some
        Some.public_fun()
      end

      defp also_calls_public_import do
        import MyCalleeModule.Some
        public_fun()
      end
    end

    defmodule MyCalleeModule.Some do
      defp public_fun do
        #     ^
        :ok
      end
    end
    """

    references = Locator.references(buffer, 18, 15, trace)

    assert references == []
  end

  test "find references with cursor over a module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee1.func()
        #                                               ^
      end
    end
    """

    references = Locator.references(buffer, 3, 53, trace)

    assert [
             %{range: %{end: %{column: 62, line: 3}, start: %{column: 58, line: 3}}, uri: nil},
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_4
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_5
             }
           ] = references

    assert range_1 ==
             %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}} |> maybe_shift

    assert range_2 ==
             %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}} |> maybe_shift

    assert range_3 ==
             %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}} |> maybe_shift

    assert range_4 ==
             %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}} |> maybe_shift

    assert range_5 ==
             %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}} |> maybe_shift
  end

  test "find references with cursor over an erlang module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        :ets.new(:s, [])
        # ^
      end
    end
    """

    references =
      Locator.references(buffer, 3, 7, trace)
      |> Enum.filter(&(&1.uri == nil or &1.uri =~ "modules_with_references"))

    assert [
             %{
               range: %{end: %{column: 13, line: 3}, start: %{column: 10, line: 3}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 ==
             %{start: %{column: 12, line: 74}, end: %{column: 15, line: 74}} |> maybe_shift
  end

  test "find references with cursor over an erlang function call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        :ets.new(:s, [])
        #     ^
      end
    end
    """

    references = Locator.references(buffer, 3, 11, trace)

    assert [
             %{
               range: %{end: %{column: 13, line: 3}, start: %{column: 10, line: 3}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 ==
             %{start: %{column: 12, line: 74}, end: %{column: 15, line: 74}} |> maybe_shift
  end

  test "find references with cursor over builtin function call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee6.module_info()
        #                                                      ^
      end
    end
    """

    references = Locator.references(buffer, 3, 60, trace)

    assert [
             %{
               range: %{end: %{column: 69, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 ==
             %{start: %{column: 60, line: 101}, end: %{column: 71, line: 101}} |> maybe_shift
  end

  test "find references with cursor over builtin function call incomplete code", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee6.module_info(
        #                                                      ^
      end
    end
    """

    references = Locator.references(buffer, 3, 60, trace)

    assert [
             %{
               range: %{end: %{column: 69, line: 3}, start: %{column: 58, line: 3}},
               uri: nil
             },
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 ==
             %{start: %{column: 60, line: 101}, end: %{column: 71, line: 101}} |> maybe_shift
  end

  defp read_line(file, range) do
    {line, column} = {range.start.line, range.start.column}

    file
    |> File.read!()
    |> Source.split_lines()
    |> Enum.at(line - 1)
    |> String.slice((column - 1)..-1//1)
  end

  defp maybe_shift(%{
         start: %{column: column_start, line: line_start},
         end: %{column: column_end, line: line_end}
       }) do
    %{
      start: %{column: column_start, line: line_start},
      end: %{column: column_end, line: line_end}
    }
  end
end
