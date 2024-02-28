defmodule ElixirLS.LanguageServer.Providers.Definition.LocatorTest do
  use ExUnit.Case, async: true
  alias ElixirLS.LanguageServer.Providers.Definition.Locator
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Source

  test "don't crash on empty buffer" do
    refute Locator.definition("", 1, 1)
  end

  test "don't error on __MODULE__ when no module" do
    assert nil == Locator.definition("__MODULE__", 1, 1)
  end

  @tag requires_elixir_1_14: true
  test "find module definition inside Phoenix's scope" do
    _define_existing_atom = ExampleWeb

    buffer = """
    defmodule ExampleWeb.Router do
      import Phoenix.Router

      scope "/", ExampleWeb do
        get "/", PageController, :home
      end
    end
    """

    %Location{type: :module, file: file, line: line, column: column} =
      Locator.definition(buffer, 5, 15)

    assert file =~ "language_server/test/support/plugins/phoenix/page_controller.ex"
    assert read_line(file, {line, column}) =~ "ExampleWeb.PageController"
  end

  test "find definition of aliased modules in `use`" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.UseExample
      use UseExample
      #        ^
    end
    """

    %Location{type: :module, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 12)

    assert file =~ "language_server/test/support/use_example.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.UseExample"
  end

  @tag requires_source: true
  test "find definition of functions from Kernel" do
    buffer = """
    defmodule MyModule do
    #^
    end
    """

    %Location{type: :macro, file: file, line: line, column: column} =
      Locator.definition(buffer, 1, 2)

    assert file =~ "lib/elixir/lib/kernel.ex"
    assert read_line(file, {line, column}) =~ "defmodule("
  end

  @tag requires_source: true
  test "find definition of functions from Kernel.SpecialForms" do
    buffer = """
    defmodule MyModule do
      import List
       ^
    end
    """

    %Location{type: :macro, file: file, line: line, column: column} =
      Locator.definition(buffer, 2, 4)

    assert file =~ "lib/elixir/lib/kernel/special_forms.ex"
    assert read_line(file, {line, column}) =~ "import"
  end

  test "find definition of functions from imports" do
    buffer = """
    defmodule MyModule do
      import ElixirSenseExample.ModuleWithFunctions
      function_arity_zero()
      #^
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 4)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_zero"
  end

  test "find definition of functions from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      MyMod.function_arity_one(42)
      #        ^
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 11)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_one"
  end

  test "find definition of macros from required modules" do
    buffer = """
    defmodule MyModule do
      require ElixirSenseExample.BehaviourWithMacrocallback.Impl, as: Macros
        Macros.some(1)
      #          ^
    end
    """

    %Location{type: :macro, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 13)

    assert file =~ "language_server/test/support/behaviour_with_macrocallbacks.ex"
    assert read_line(file, {line, column}) =~ "some"
  end

  test "find definition of functions piped from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      42 |> MyMod.function_arity_one()
      #              ^
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 17)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_one"
  end

  test "find definition of functions captured from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      &MyMod.function_arity_one/1
      #              ^
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 17)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_one"
  end

  test "find function definition macro generated" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.MacroGenerated, as: Local
      Local.my_fun()
      #        ^
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 12)

    assert file =~ "language_server/test/support/macro_generated.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.Macros.go"
  end

  test "find metadata module" do
    buffer = """
    defmodule Some do
      def my_func, do: "not this one"
    end

    defmodule MyModule do
      def main, do: Some.my_func()
      #               ^
    end
    """

    assert %Location{type: :module, file: nil, line: 1, column: 1} =
             Locator.definition(buffer, 6, 19)
  end

  @tag capture_log: true
  test "find remote module" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: MyMod
      def main, do: MyMod.my_func()
      #               ^
    end
    """

    assert %Location{type: :module, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 19)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"

    assert read_line(file, {line, column}) =~
             "defmodule ElixirSenseExample.FunctionsWithDefaultArgs do"
  end

  @tag capture_log: true
  test "find remote module - fallback to docs" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs1, as: MyMod
      def main, do: MyMod.my_func()
      #               ^
    end
    """

    assert %Location{type: :module, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 19)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "@moduledoc \"example module\""
  end

  test "find definition for the correct arity of function - on fn call" do
    buffer = """
    defmodule MyModule do
      def main, do: my_func("a", "b")
      #               ^
      def my_func, do: "not this one"
      def my_func(a, b), do: a <> b
    end
    """

    assert %Location{type: :function, file: nil, line: 5, column: 3} =
             Locator.definition(buffer, 2, 18)
  end

  test "find definition for the correct arity of function - on fn call with default arg" do
    buffer = """
    defmodule MyModule do
      def main, do: my_func("a")
      #               ^
      def my_func, do: "not this one"
      def my_func(a, b \\\\ ""), do: a <> b
    end
    """

    assert %Location{type: :function, file: nil, line: 5, column: 3} =
             Locator.definition(buffer, 2, 18)
  end

  test "find metadata function head for the correct arity of function - on fn call with default arg" do
    buffer = """
    defmodule MyModule do
      def main, do: {my_func(), my_func("a"), my_func(1, 2, 3)}
      #                          ^
      def my_func, do: "not this one"
      def my_func(a, b \\\\ "")
      def my_func(1, b), do: "1" <> b
      def my_func(2, b), do: "2" <> b
      def my_func(1, 2, 3), do: :ok
    end
    """

    assert %Location{type: :function, file: nil, line: 5, column: 3} =
             Locator.definition(buffer, 2, 30)
  end

  @tag capture_log: true
  test "find remote function head for the correct arity of function - on fn call with default arg" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def main, do: {F.my_func(), F.my_func("a"), F.my_func(1, 2, 3)}
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 34)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "my_func(a, b \\\\ \"\")"
  end

  @tag capture_log: true
  test "find remote function head for the lowest matching arity of function in incomplete code" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def main, do: F.my_func(
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "def my_func,"

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def main, do: F.my_func(1
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "def my_func(a, b \\\\ \"\")"

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def main, do: F.my_func(1, 2,
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "def my_func(1, 2, 3)"

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def main, do: F.my_func(1, 2, 3,
    end
    """

    # too many arguments

    assert nil == Locator.definition(buffer, 3, 20)
  end

  @tag capture_log: true
  test "find remote function head for the correct arity of function - on fn call with default arg - fallback to docs" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs1, as: F
      def main, do: {F.my_func(), F.my_func("a"), F.my_func(1, 2, 3)}
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 34)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "@doc \"2 params version\""
  end

  @tag capture_log: true
  test "find remote function head for the lowest matching arity of function in incomplete code - fallback to docs" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs1, as: F
      def main, do: F.my_func(
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "@doc \"no params version\""

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs1, as: F
      def main, do: F.my_func(1
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "@doc \"2 params version\""

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs1, as: F
      def main, do: F.my_func(1, 2,
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "@doc \"3 params version\""

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs1, as: F
      def main, do: F.my_func(1, 2, 3,
    end
    """

    # too many arguments

    assert nil == Locator.definition(buffer, 3, 20)
  end

  @tag capture_log: true
  test "find remote function head for the correct arity of function - on function capture" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
      def main, do: &F.my_func/1
    end
    """

    assert %Location{type: :function, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 21)

    assert file =~ "language_server/test/support/functions_with_default_args.ex"
    assert read_line(file, {line, column}) =~ "my_func(a, b \\\\ \"\")"
  end

  test "find definition for the correct arity of function - on fn call with pipe" do
    buffer = """
    defmodule MyModule do
      def main, do: "a" |> my_func("b")
      #                     ^
      def my_func, do: "not this one"
      def my_func(a, b), do: a <> b
    end
    """

    assert %Location{type: :function, file: nil, line: 5, column: 3} =
             Locator.definition(buffer, 2, 24)
  end

  test "find definition for the correct arity of function - on fn definition" do
    buffer = """
    defmodule MyModule do
      def my_func, do: "not this one"
      def my_func(a, b \\\\ nil)
      def my_func(a, b), do: a <> b
    end
    """

    assert %Location{type: :function, file: nil, line: 3, column: 3} =
             Locator.definition(buffer, 4, 9)
  end

  test "find definition for function - on var call" do
    buffer = """
    defmodule A do
      @callback abc() :: any()
    end

    defmodule B do
      @behaviour A

      def abc, do: :ok
    end

    b = B
    b.abc()
    """

    assert %Location{type: :function, file: nil, line: 8, column: 3} =
             Locator.definition(buffer, 12, 4)
  end

  test "find definition of delegated functions" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      MyMod.delegated_function()
      #        ^
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 11)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "delegated_function"
  end

  test "find definition of modules" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      ElixirSenseExample.ModuleWithFunctions.function_arity_zero()
      #                   ^
    end
    """

    %Location{type: :module, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 23)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.ModuleWithFunctions do"
  end

  test "find definition of modules in multi alias syntax" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithDocs
      alias ElixirSenseExample.{Some, ModuleWithDocs}
    end
    """

    %Location{type: :module, file: file_1, line: line_1} = Locator.definition(buffer, 2, 30)

    %Location{type: :module, file: file_2, line: line_2} = Locator.definition(buffer, 3, 38)

    assert file_1 == file_2
    assert line_1 == line_2
  end

  test "find definition of erlang modules" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
        # ^
      end
    end
    """

    %Location{type: :module, file: file, line: 20, column: 1} =
      Locator.definition(buffer, 3, 7)

    assert file =~ "/src/lists.erl"
  end

  test "find definition of remote erlang functions" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
        #         ^
      end
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 15)

    assert file =~ "/src/lists.erl"
    assert read_line(file, {line, column}) =~ "duplicate(N, X)"
  end

  test "find definition of remote erlang functions from preloaded module" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :erlang.start_timer(2, x, 4)
        #         ^
      end
    end
    """

    %Location{type: :function, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 15)

    assert file =~ "/src/erlang.erl"
    assert read_line(file, {line, column}) =~ "start_timer(_Time, _Dest, _Msg)"
  end

  test "non existing modules" do
    buffer = """
    defmodule MyModule do
      SilverBulletModule.run
    end
    """

    refute Locator.definition(buffer, 2, 24)
  end

  test "cannot find map field calls" do
    buffer = """
    defmodule MyModule do
      env = __ENV__
      IO.puts(env.file)
      #            ^
    end
    """

    refute Locator.definition(buffer, 3, 16)
  end

  test "cannot find map fields" do
    buffer = """
    defmodule MyModule do
      var = %{count: 1}
      #        ^
    end
    """

    refute Locator.definition(buffer, 2, 12)
  end

  test "preloaded modules" do
    buffer = """
    defmodule MyModule do
      :erlang.node
      # ^
    end
    """

    assert %Location{line: 20, column: 1, type: :module, file: file} =
             Locator.definition(buffer, 2, 5)

    assert file =~ "/src/erlang.erl"
  end

  test "find built-in functions" do
    # module_info is defined by default for every elixir and erlang module
    # __info__ is defined for every elixir module
    # behaviour_info is defined for every behaviour and every protocol
    buffer = """
    defmodule MyModule do
      ElixirSenseExample.ModuleWithFunctions.module_info()
      #                                      ^
      ElixirSenseExample.ModuleWithFunctions.__info__(:macros)
      #                                      ^
      ElixirSenseExample.ExampleBehaviour.behaviour_info(:callbacks)
      #                                      ^
    end
    """

    assert %{column: column, file: file, line: line, type: :function} =
             Locator.definition(buffer, 2, 42)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.ModuleWithFunctions do"

    assert %Location{type: :function} = Locator.definition(buffer, 4, 42)

    assert %Location{type: :function} = Locator.definition(buffer, 6, 42)
  end

  test "built-in functions cannot be called locally" do
    # module_info is defined by default for every elixir and erlang module
    # __info__ is defined for every elixir module
    # behaviour_info is defined for every behaviour and every protocol
    buffer = """
    defmodule MyModule do
      import GenServer
      @ callback cb() :: term
      module_info()
      #^
      __info__(:macros)
      #^
      behaviour_info(:callbacks)
      #^
    end
    """

    refute Locator.definition(buffer, 4, 5)

    refute Locator.definition(buffer, 6, 5)

    refute Locator.definition(buffer, 8, 5)
  end

  test "does not find built-in erlang functions" do
    buffer = """
    defmodule MyModule do
      :erlang.orelse()
      #         ^
      :erlang.or()
      #       ^
    end
    """

    refute Locator.definition(buffer, 2, 14)

    refute Locator.definition(buffer, 4, 12)
  end

  test "find definition of variables" do
    buffer = """
    defmodule MyModule do
      def func do
        var1 = 1
        var2 = 2
        var1 = 3
        IO.puts(var1 + var2)
      end
    end
    """

    assert Locator.definition(buffer, 6, 13) == %Location{
             type: :variable,
             file: nil,
             line: 5,
             column: 5
           }

    assert Locator.definition(buffer, 6, 21) == %Location{
             type: :variable,
             file: nil,
             line: 4,
             column: 5
           }
  end

  test "find definition of variables defined on the next line" do
    buffer = """
    defmodule MyModule do
      def func do
        var1 =
          1
      end
    end
    """

    assert Locator.definition(buffer, 3, 5) == %Location{
             type: :variable,
             file: nil,
             line: 3,
             column: 5
           }
  end

  test "find definition of functions when name not same as variable" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 6, 6) == %Location{
             type: :function,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "find definition of functions when name same as variable - parens preferes function" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun = 1
        my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 6, 6) == %Location{
             type: :function,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "find definition of variables when name same as function - no parens preferes variable" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun = 1
        my_fun
      end
    end
    """

    assert Locator.definition(buffer, 6, 6) == %Location{
             type: :variable,
             file: nil,
             line: 5,
             column: 5
           }
  end

  test "find definition of variables when name same as function" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :error

      def a do
        my_fun = fn -> :ok end
        my_fun.()
      end
    end
    """

    assert Locator.definition(buffer, 6, 6) == %Location{
             type: :variable,
             file: nil,
             line: 5,
             column: 5
           }
  end

  test "find definition for a redefined variable" do
    buffer = """
    defmodule MyModule do
      def my_fun(var) do
        var = 1 + var

        var
      end
    end
    """

    # `var` defined in the function header
    assert Locator.definition(buffer, 3, 15) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 14
           }

    # `var` redefined in the function body
    assert Locator.definition(buffer, 5, 5) == %Location{
             type: :variable,
             file: nil,
             line: 3,
             column: 5
           }
  end

  test "find definition of a variable in a guard" do
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

    assert Locator.definition(buffer, 2, 32) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 14
           }

    assert Locator.definition(buffer, 4, 16) == %Location{
             type: :variable,
             file: nil,
             line: 4,
             column: 7
           }

    assert Locator.definition(buffer, 7, 32) == %Location{
             type: :variable,
             file: nil,
             line: 7,
             column: 25
           }
  end

  test "find definition of variables when variable is a function parameter" do
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
    assert Locator.definition(buffer, 3, 11) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 15
           }

    assert Locator.definition(buffer, 6, 7) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 15
           }

    # `h` from the if-else scope
    assert Locator.definition(buffer, 9, 7) == %Location{
             type: :variable,
             file: nil,
             line: 8,
             column: 7
           }

    # `t`
    assert Locator.definition(buffer, 8, 18) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 19
           }

    # `sum`
    assert Locator.definition(buffer, 8, 23) == %Location{
             type: :variable,
             file: nil,
             line: 3,
             column: 5
           }
  end

  test "find definition of variables from the scope of an anonymous function" do
    buffer = """
    defmodule MyModule do
      def my_fun(x, y) do
        x = Enum.map(x, fn x -> x + y end)
      end
    end
    """

    # `x` from the `my_fun` function header
    assert Locator.definition(buffer, 3, 18) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 14
           }

    # `y` from the `my_fun` function header
    assert Locator.definition(buffer, 3, 33) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 17
           }

    # `x` from the anonymous function
    assert Locator.definition(buffer, 3, 29) == %Location{
             type: :variable,
             file: nil,
             line: 3,
             column: 24
           }

    # redefined `x`
    assert Locator.definition(buffer, 3, 5) == %Location{
             type: :variable,
             file: nil,
             line: 3,
             column: 5
           }
  end

  test "find definition of variables inside multiline struct" do
    buffer = """
    defmodule MyModule do
      def go do
        %Some{
          filed: var
        } = abc()
      end
    end
    """

    assert Locator.definition(buffer, 4, 15) == %Location{
             type: :variable,
             file: nil,
             line: 4,
             column: 14
           }
  end

  test "find definition of a variable when using pin operator" do
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
    assert Locator.definition(buffer, 4, 8) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 17
           }

    assert Locator.definition(buffer, 4, 13) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 17
           }

    assert Locator.definition(buffer, 5, 13) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 17
           }

    assert Locator.definition(buffer, 5, 23) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 17
           }

    # `a` redefined in a case clause
    assert Locator.definition(buffer, 5, 18) == %Location{
             type: :variable,
             file: nil,
             line: 5,
             column: 18
           }
  end

  test "find definition of attributes" do
    buffer = """
    defmodule MyModule do
      def func do
        @var1 1
        @var2 2
        @var1 3
        IO.puts(@var1 + @var2)
      end
    end
    """

    assert Locator.definition(buffer, 6, 15) == %Location{
             type: :attribute,
             file: nil,
             line: 3,
             column: 5
           }

    assert Locator.definition(buffer, 6, 24) == %Location{
             type: :attribute,
             file: nil,
             line: 4,
             column: 5
           }
  end

  test "find definition of local functions with default args" do
    buffer = """
    defmodule MyModule do
      def my_fun(a \\\\ 0, b \\\\ nil), do: :ok

      def a do
        my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 5, 6) == %Location{
             type: :function,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "find definition of local __MODULE__" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        __MODULE__.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 6, 6) == %Location{
             type: :module,
             file: nil,
             line: 1,
             column: 1
           }
  end

  test "find definition of local functions with __MODULE__" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        __MODULE__.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 6, 17) == %Location{
             type: :function,
             file: nil,
             line: 2,
             column: 3
           }
  end

  @tag requires_elixir_1_14: true
  test "find definition of local functions with __MODULE__ submodule" do
    buffer = """
    defmodule MyModule do
      defmodule Sub do
        def my_fun(), do: :ok
      end

      def a do
        my_fun1 = 1
        __MODULE__.Sub.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 8, 22) == %Location{
             type: :function,
             file: nil,
             line: 3,
             column: 5
           }
  end

  @tag requires_elixir_1_14: true
  test "find definition of local __MODULE__ submodule" do
    buffer = """
    defmodule MyModule do
      defmodule Sub do
        def my_fun(), do: :ok
      end

      def a do
        my_fun1 = 1
        __MODULE__.Sub.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 8, 17) == %Location{
             type: :module,
             file: nil,
             line: 2,
             column: 3
           }
  end

  @tag requires_elixir_1_14: true
  test "find definition of local functions with @attr" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok
      @attr MyModule
      def a do
        my_fun1 = 1
        @attr.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 6, 13) == %Location{
             type: :function,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "find definition of local functions with current module" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        MyModule.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 6, 14) == %Location{
             type: :function,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "find definition of local macro" do
    buffer = """
    defmodule MyModule do
      defmacrop some(var), do: Macro.expand(var, __CALLER__)

      defmacro other do
        some(1)
      end
    end
    """

    assert Locator.definition(buffer, 5, 6) == %Location{
             type: :macro,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "find definition of local macro on definition" do
    buffer = """
    defmodule MyModule do
      defmacrop some(var), do: Macro.expand(var, __CALLER__)

      defmacro other do
        some(1)
      end
    end
    """

    assert Locator.definition(buffer, 2, 14) == %Location{
             type: :macro,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "does not find definition of local macro if it's defined after the cursor" do
    buffer = """
    defmodule MyModule do
      defmacro other do
        some(1)
      end

      defmacrop some(var), do: Macro.expand(var, __CALLER__)
    end
    """

    assert Locator.definition(buffer, 3, 6) == nil
  end

  test "find definition of local function even if it's defined after the cursor" do
    buffer = """
    defmodule MyModule do
      def other do
        some(1)
      end

      defp some(var), do: :ok
    end
    """

    assert Locator.definition(buffer, 3, 6) == %Location{
             type: :function,
             file: nil,
             line: 6,
             column: 3
           }
  end

  test "find definition of local functions with alias" do
    buffer = """
    defmodule MyModule do
      alias MyModule, as: M
      def my_fun(), do: :ok
      def my_fun(a), do: :ok

      def a do
        my_fun1 = 1
        M.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 8, 7) == %Location{
             type: :function,
             file: nil,
             line: 3,
             column: 3
           }
  end

  test "do not find private function definition" do
    buffer = """
    defmodule MyModule do
      defmodule Submodule do
        defp my_fun(), do: :ok
      end

      def a do
        MyModule.Submodule.my_fun()
      end
    end
    """

    refute Locator.definition(buffer, 7, 25)
  end

  test "find definition of local module" do
    buffer = """
    defmodule MyModule do
      defmodule Submodule do
        def my_fun(), do: :ok
      end

      def a do
        MyModule.Submodule.my_fun()
      end
    end
    """

    assert Locator.definition(buffer, 7, 16) == %Location{
             type: :module,
             file: nil,
             line: 2,
             column: 3
           }
  end

  test "find definition of params" do
    buffer = """
    defmodule MyModule do
      def func(%{a: [var2|_]}) do
        var1 = 3
        IO.puts(var1 + var2)
        #               ^
      end
    end
    """

    assert Locator.definition(buffer, 4, 21) == %Location{
             type: :variable,
             file: nil,
             line: 2,
             column: 18
           }
  end

  test "find remote type definition" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithTypespecs.Remote
      @type a :: Remote.remote_t
      #                    ^
    end
    """

    %Location{type: :typespec, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 24)

    assert file =~ "language_server/test/support/module_with_typespecs.ex"
    assert read_line(file, {line, column}) =~ ~r/^@type remote_t/
  end

  test "find type definition without @typedoc" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithTypespecs.Remote
      @type a :: Remote.remote_option_t
      #                    ^
    end
    """

    %Location{type: :typespec, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 24)

    assert file =~ "language_server/test/support/module_with_typespecs.ex"
    assert read_line(file, {line, column}) =~ ~r/@type remote_option_t ::/
  end

  test "find opaque type definition" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithTypespecs.Local
      @type a :: Local.opaque_t
      #                   ^
    end
    """

    %Location{type: :typespec, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 23)

    assert file =~ "language_server/test/support/module_with_typespecs.ex"
    assert read_line(file, {line, column}) =~ ~r/@opaque opaque_t/
  end

  test "find type definition macro generated" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.MacroGenerated, as: Local
      @type a :: Local.my_type
      #                   ^
    end
    """

    %Location{type: :typespec, file: file, line: line, column: column} =
      Locator.definition(buffer, 3, 23)

    assert file =~ "language_server/test/support/macro_generated.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.Macros.go"
  end

  test "find erlang type definition" do
    buffer = """
    defmodule MyModule do
      @type a :: :ets.tab
      #                ^
    end
    """

    %Location{type: :typespec, file: file, line: line, column: column} =
      Locator.definition(buffer, 2, 20)

    assert file =~ "/src/ets.erl"
    assert read_line(file, {line, column}) =~ "-type tab()"
  end

  test "find erlang type definition from preloaded module" do
    buffer = """
    defmodule MyModule do
      @type a :: :erlang.time_unit
      #                   ^
    end
    """

    %Location{type: :typespec, file: file, line: line, column: column} =
      Locator.definition(buffer, 2, 23)

    assert file =~ "/src/erlang.erl"
    assert read_line(file, {line, column}) =~ "-type time_unit()"
  end

  test "do not find erlang private type" do
    buffer = """
    defmodule MyModule do
      @type a :: :erlang.memory_type
      #                   ^
    end
    """

    refute Locator.definition(buffer, 2, 23)
  end

  test "builtin types cannot be found" do
    buffer = """
    defmodule MyModule do
      @type my_type :: integer
      #                   ^
    end
    """

    refute Locator.definition(buffer, 2, 23)
  end

  test "builtin elixir types cannot be found" do
    buffer = """
    defmodule MyModule do
      @type my_type :: Elixir.keyword
      #                         ^
    end
    """

    refute Locator.definition(buffer, 2, 29)
  end

  test "find local metadata type definition" do
    buffer = """
    defmodule MyModule do
      @typep my_t :: integer

      @type remote_list_t :: [my_t]
      #                         ^
    end
    """

    %Location{type: :typespec, file: nil, line: 2, column: 3} =
      Locator.definition(buffer, 4, 29)
  end

  test "find local metadata type definition even if it's defined after cursor" do
    buffer = """
    defmodule MyModule do
      @type remote_list_t :: [my_t]
      #                         ^

      @typep my_t :: integer
    end
    """

    %Location{type: :typespec, file: nil, line: 5, column: 3} =
      Locator.definition(buffer, 2, 29)
  end

  test "find remote metadata type definition" do
    buffer = """
    defmodule MyModule.Other do
      @type my_t :: integer
      @type my_t(a) :: {a, integer}
    end

    defmodule MyModule do
      alias MyModule.Other

      @type remote_list_t :: [Other.my_t]
      #                               ^
    end
    """

    %Location{type: :typespec, file: nil, line: 2, column: 3} =
      Locator.definition(buffer, 9, 35)
  end

  test "do not find remote private type definition" do
    buffer = """
    defmodule MyModule.Other do
      @typep my_t :: integer
      @typep my_t(a) :: {a, integer}
    end

    defmodule MyModule do
      alias MyModule.Other

      @type remote_list_t :: [Other.my_t]
      #                               ^
    end
    """

    refute Locator.definition(buffer, 9, 35)
  end

  test "find metadata type for the correct arity" do
    buffer = """
    defmodule MyModule do
      @type my_type :: integer
      @type my_type(a) :: {integer, a}
      @type my_type(a, b) :: {integer, a, b}
      @type some :: {my_type, my_type(boolean), my_type(integer, integer)}
    end
    """

    assert %Location{type: :typespec, file: nil, line: 3, column: 3} =
             Locator.definition(buffer, 5, 28)
  end

  test "find metadata type for the correct arity - on type definition" do
    buffer = """
    defmodule MyModule do
      @type my_type :: integer
      @type my_type(a) :: {integer, a}
      @type my_type(a, b) :: {integer, a, b}
    end
    """

    assert %Location{type: :typespec, file: nil, line: 3, column: 3} =
             Locator.definition(buffer, 3, 10)
  end

  test "find remote type for the correct arity" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity, as: T
      @type some :: {T.my_type, T.my_type(boolean), T.my_type(1, 2)}
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 32)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "my_type(a)"
  end

  test "find remote type for lowest matching arity in incomplete code" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity, as: T
      @type some :: T.my_type(
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "@type my_type :: integer"

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity, as: T
      @type some :: T.my_type(integer
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "@type my_type(a) :: {integer, a}"

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity, as: T
      @type some :: T.my_type(integer,
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "@type my_type(a, b) :: {integer, a, b}"

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity, as: T
      @type some :: T.my_type(integer, integer,
    end
    """

    # too many arguments

    assert nil == Locator.definition(buffer, 3, 20)
  end

  @tag capture_log: true
  test "find remote type for the correct arity - fallback to docs" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity1, as: T
      @type some :: {T.my_type, T.my_type(boolean), T.my_type(1, 2)}
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 32)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "@typedoc \"one param version\""
  end

  @tag capture_log: true
  test "find remote type for lowest matching arity in incomplete code - fallback to docs" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity1, as: T
      @type some :: T.my_type(
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "@typedoc \"no params version\""

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity1, as: T
      @type some :: T.my_type(integer
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "@typedoc \"one param version\""

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity1, as: T
      @type some :: T.my_type(integer,
    end
    """

    assert %Location{type: :typespec, file: file, line: line, column: column} =
             Locator.definition(buffer, 3, 20)

    assert file =~ "language_server/test/support/types_with_multiple_arity.ex"
    assert read_line(file, {line, column}) =~ "@typedoc \"two params version\""

    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.TypesWithMultipleArity1, as: T
      @type some :: T.my_type(integer, integer,
    end
    """

    # too many arguments

    assert nil == Locator.definition(buffer, 3, 20)
  end

  test "find super inside overridable function" do
    buffer = """
    defmodule MyModule do
      use ElixirSenseExample.OverridableFunctions

      def test(x, y) do
        super(x, y)
      end

      defmacro required(v) do
        super(v)
      end
    end
    """

    assert %Location{type: :macro, file: file, line: line, column: column} =
             Locator.definition(buffer, 5, 6)

    assert file =~ "language_server/test/support/overridable_function.ex"
    assert read_line(file, {line, column}) =~ "__using__(_opts)"

    assert %Location{type: :macro, file: file, line: line, column: column} =
             Locator.definition(buffer, 9, 6)

    assert file =~ "language_server/test/support/overridable_function.ex"
    assert read_line(file, {line, column}) =~ "__using__(_opts)"
  end

  test "find super inside overridable callback" do
    buffer = """
    defmodule MyModule do
      use ElixirSenseExample.OverridableImplementation

      def foo do
        super()
      end

      defmacro bar(any) do
        super(any)
      end
    end
    """

    assert %Location{type: :macro, file: file, line: line, column: column} =
             Locator.definition(buffer, 5, 6)

    assert file =~ "language_server/test/support/overridable_function.ex"
    assert read_line(file, {line, column}) =~ "__using__(_opts)"

    assert %Location{type: :macro, file: file, line: line, column: column} =
             Locator.definition(buffer, 9, 6)

    assert file =~ "language_server/test/support/overridable_function.ex"
    assert read_line(file, {line, column}) =~ "__using__(_opts)"
  end

  test "find super inside overridable callback when module is compiled" do
    buffer = """
    defmodule ElixirSenseExample.OverridableImplementation.Overrider do
      use ElixirSenseExample.OverridableImplementation

      def foo do
        super()
      end

      defmacro bar(any) do
        super(any)
      end
    end
    """

    assert %Location{type: :macro, file: file, line: line, column: column} =
             Locator.definition(buffer, 5, 6)

    assert file =~ "language_server/test/support/overridable_function.ex"
    assert read_line(file, {line, column}) =~ "__using__(_opts)"

    assert %Location{type: :macro, file: file, line: line, column: column} =
             Locator.definition(buffer, 9, 6)

    assert file =~ "language_server/test/support/overridable_function.ex"
    assert read_line(file, {line, column}) =~ "__using__(_opts)"
  end

  test "find local type in typespec local def elsewhere" do
    buffer = """
    defmodule ElixirSenseExample.Some do
      @type some_local :: integer

      def some_local(), do: :ok

      @type user :: {some_local, integer}

      def foo do
        some_local
      end
    end
    """

    assert %Location{type: :typespec, file: nil, line: 2} = Locator.definition(buffer, 6, 20)

    assert %Location{type: :function, file: nil, line: 4} = Locator.definition(buffer, 9, 9)
  end

  test "find variable with the same name as special form" do
    buffer = """
    defmodule ElixirSenseExample.Some do
      def foo do
        quote = 123
        abc(quote)
      end
    end
    """

    assert %Location{type: :variable, file: nil, line: 3} = Locator.definition(buffer, 4, 10)
  end

  defp read_line(file, {line, column}) do
    file
    |> File.read!()
    |> Source.split_lines()
    |> Enum.at(line - 1)
    |> String.slice((column - 1)..-1//1)
  end
end
