# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Implementation.LocatorTest do
  use ExUnit.Case, async: true
  alias ElixirLS.LanguageServer.Providers.Implementation.Locator
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Source

  test "don't crash on empty buffer" do
    assert [] == Locator.implementations("", 1, 1)
  end

  test "don't error on __MODULE__ when no module" do
    assert [] == Locator.implementations("__MODULE__", 1, 1)
  end

  test "don't error on Elixir" do
    assert [] == Locator.implementations("Elixir", 1, 1)
  end

  test "don't error on not existing module" do
    assert [] == Locator.implementations("SomeNotExistingMod", 1, 1)
  end

  test "don't error on non behaviour module" do
    assert [] == Locator.implementations("ElixirSenseExample.EmptyModule", 1, 32)
  end

  test "don't error on erlang function calls" do
    assert [] == Locator.implementations(":ets.new", 1, 8)
  end

  test "don't return implementations for non callback functions on behaviour" do
    assert [] == Locator.implementations("GenServer.start_link", 1, 12)
  end

  test "don't error on non behaviour module function" do
    buffer = """
    defmodule ElixirSenseExample.EmptyModule do
      def abc(), do: :ok
    end
    """

    assert [] == Locator.implementations(buffer, 2, 8)
  end

  test "don't error on builtin macro" do
    buffer = """
    defmodule ElixirSenseExample.EmptyModule do
      def abc(), do: :ok
    end
    """

    assert [] == Locator.implementations(buffer, 1, 8)
  end

  test "find implementations of behaviour module" do
    buffer = """
    defmodule ElixirSenseExample.ExampleBehaviourWithDoc do
    end
    """

    [
      %Location{type: :module, file: file1, line: line1, column: column1},
      %Location{type: :module, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 1, 32)

    assert file1 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file1, {line1, column1}) =~
             "ElixirSenseExample.ExampleBehaviourWithDocCallbackImpl"

    assert file2 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file2, {line2, column2}) =~
             "ElixirSenseExample.ExampleBehaviourWithDocCallbackNoImpl"
  end

  test "find protocol implementations" do
    buffer = """
    defprotocol ElixirSenseExample.ExampleProtocol do
    end
    """

    [
      %Location{type: :module, file: file1, line: line1, column: column1},
      %Location{type: :module, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 1, 32) |> Enum.sort()

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "ElixirSenseExample.ExampleProtocol, for: List"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "ElixirSenseExample.ExampleProtocol, for: Map"
  end

  test "find implementations of behaviour module callback" do
    buffer = """
    defmodule ElixirSenseExample.ExampleBehaviourWithDoc do
      @callback foo() :: :ok
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 2, 14)

    assert file1 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file1, {line1, column1}) =~
             "foo(), do: :ok"

    assert file2 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file2, {line2, column2}) =~
             "foo(), do: :ok"
  end

  test "find implementations of behaviour module macrocallback" do
    buffer = """
    defmodule ElixirSenseExample.ExampleBehaviourWithDoc do
      @macrocallback bar(integer()) :: Macro.t()
    end
    """

    [
      %Location{type: :macro, file: file1, line: line1, column: column1},
      %Location{type: :macro, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 2, 19)

    assert file1 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file1, {line1, column1}) =~
             "defmacro bar(_b)"

    assert file2 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file2, {line2, column2}) =~
             "defmacro bar(_b)"
  end

  test "find implementations of behaviour module on callback in implementation" do
    buffer = """
    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithDoc
      def foo(), do: :ok
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2},
      %Location{type: :function, file: nil, line: 3, column: 3}
    ] = Locator.implementations(buffer, 3, 8)

    assert file1 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file1, {line1, column1}) =~
             "foo(), do: :ok"

    assert file2 =~ "language_server/test/support/example_behaviour.ex"

    assert read_line(file2, {line2, column2}) =~
             "foo(), do: :ok"
  end

  test "find implementations of metadata behaviour module callback" do
    buffer = """
    defmodule MetadataBehaviour do
      @callback foo() :: :ok
    end

    defmodule Some do
      @behaviour MetadataBehaviour
      def foo(), do: :ok
    end
    """

    [
      %Location{type: :function, file: nil, line: 7, column: 3}
    ] = Locator.implementations(buffer, 2, 14)
  end

  test "find implementations of metadata behaviour module macrocallback" do
    buffer = """
    defmodule MetadataBehaviour do
      @macrocallback foo(arg :: any) :: Macro.t
    end

    defmodule Some do
      @behaviour MetadataBehaviour
      defmacro foo(arg), do: :ok
    end
    """

    [
      %Location{type: :macro, file: nil, line: 7, column: 3}
    ] = Locator.implementations(buffer, 2, 19)
  end

  test "find implementations of metadata behaviour module macrocallback when implementation is a guard" do
    buffer = """
    defmodule MetadataBehaviour do
      @macrocallback foo(arg :: any) :: Macro.t
    end

    defmodule Some do
      @behaviour MetadataBehaviour
      defguard foo(arg) when is_nil(arg)
    end
    """

    [
      %Location{type: :macro, file: nil, line: 7, column: 3}
    ] = Locator.implementations(buffer, 2, 19)
  end

  test "find implementations of metadata behaviour" do
    buffer = """
    defmodule MetadataBehaviour do
      @callback foo() :: :ok
    end

    defmodule Some do
      @behaviour MetadataBehaviour
      def foo(), do: :ok
    end
    """

    [
      %Location{type: :module, file: nil, line: 5, column: 1}
    ] = Locator.implementations(buffer, 1, 14)
  end

  test "find protocol implementation functions" do
    buffer = """
    defprotocol ElixirSenseExample.ExampleProtocol do
      @spec some(t) :: any
      def some(t)
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 3, 8)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"
  end

  test "find protocol implementation functions on spec" do
    buffer = """
    defprotocol ElixirSenseExample.ExampleProtocol do
      @spec some(t) :: any
      def some(t)
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 2, 10)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"
  end

  test "find metadata protocol implementation functions on spec" do
    buffer = """
    defprotocol MetadataProtocol do
      @spec some(t) :: any
      def some(t)
    end

    defimpl MetadataProtocol, for: String do
      def some(t), do: :ok
    end
    """

    [
      %Location{type: :function, file: nil, line: 7, column: 3}
    ] = Locator.implementations(buffer, 2, 10)
  end

  test "find protocol implementation functions on implementation function" do
    buffer = """
    defimpl ElixirSenseExample.ExampleProtocol, for: String do
      def some(t), do: t
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2},
      %Location{type: :function, file: nil, line: 2, column: 3}
    ] = Locator.implementations(buffer, 2, 8)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"
  end

  test "find metadata protocol implementation functions on function" do
    buffer = """
    defprotocol MetadataProtocol do
      @spec some(t) :: any
      def some(t)
    end

    defimpl MetadataProtocol, for: String do
      def some(t), do: :ok
    end
    """

    [
      %Location{type: :function, file: nil, line: 7, column: 3}
    ] = Locator.implementations(buffer, 3, 8)
  end

  test "find metadata protocol implementation functions on function when implementation is a delegate" do
    buffer = """
    defprotocol MetadataProtocol do
      @spec some(t) :: any
      def some(t)
    end

    defimpl MetadataProtocol, for: String do
      defdelegate some(t), to: Impl
    end
    """

    [
      %Location{type: :function, file: nil, line: 7, column: 3}
    ] = Locator.implementations(buffer, 3, 8)
  end

  test "find metadata protocol implementation" do
    buffer = """
    defprotocol MetadataProtocol do
      @spec some(t) :: any
      def some(t)
    end

    defimpl MetadataProtocol, for: String do
      def some(t), do: :ok
    end
    """

    [
      %Location{type: :module, file: nil, line: 6, column: 1}
    ] = Locator.implementations(buffer, 1, 14)
  end

  test "find protocol implementation functions on implementation function - incomplete code" do
    buffer = """
    defimpl ElixirSenseExample.ExampleProtocol, for: String do
      def some(t
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2},
      %Location{type: :function, file: nil, line: 2, column: 3}
    ] = Locator.implementations(buffer, 2, 8)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"

    buffer = """
    defimpl ElixirSenseExample.ExampleProtocol, for: String do
      def some(t, 1,
    end
    """

    # too many arguments

    assert [] = Locator.implementations(buffer, 2, 8)
  end

  test "find protocol implementation functions on call" do
    buffer = """
    ElixirSenseExample.ExampleProtocol.some(1)
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 1, 37)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"
  end

  test "find protocol implementation functions on call with incomplete code" do
    buffer = """
    ElixirSenseExample.ExampleProtocol.some(
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 1, 37)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"

    buffer = """
    ElixirSenseExample.ExampleProtocol.some(a,
    """

    # too many arguments

    assert [] = Locator.implementations(buffer, 1, 37)
  end

  test "find protocol implementation functions on call with alias" do
    buffer = """
    defmodule Some do
      alias ElixirSenseExample.ExampleProtocol, as: A
      A.some(1)
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 3, 6)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"
  end

  test "find protocol implementation functions on call via @attr" do
    buffer = """
    defmodule Some do
      @attr ElixirSenseExample.ExampleProtocol
      @attr.some(1)
    end
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2}
    ] = Locator.implementations(buffer, 3, 10)

    assert file1 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file1, {line1, column1}) =~ "some(t), do: t"

    assert file2 =~ "language_server/test/support/example_protocol.ex"
    assert read_line(file2, {line2, column2}) =~ "some(t), do: t"
  end

  test "find behaviour implementation functions on call" do
    buffer = """
    ElixirSenseExample.DummyBehaviourImplementation.foo()
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1}
    ] = Locator.implementations(buffer, 1, 49)

    assert file1 =~ "language_server/test/support/behaviour_implementations.ex"
    assert read_line(file1, {line1, column1}) =~ "def foo(), do: :ok"
  end

  test "find behaviour implementation functions on call metadata" do
    buffer = """
    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithDoc
      def foo(), do: :ok
    end

    Some.foo()
    """

    [
      %Location{type: :function, file: file1, line: line1, column: column1},
      %Location{type: :function, file: file2, line: line2, column: column2},
      %Location{type: :function, file: nil, line: 3, column: 3}
    ] = Locator.implementations(buffer, 6, 7)

    assert file1 =~ "language_server/test/support/example_behaviour.ex"
    assert read_line(file1, {line1, column1}) =~ "def foo(), do: :ok"

    assert file2 =~ "language_server/test/support/example_behaviour.ex"
    assert read_line(file2, {line2, column2}) =~ "def foo(), do: :ok"
  end

  test "find behaviour macrocallback implementation functions on call metadata" do
    buffer = """
    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithDoc
      defmacro bar(a), do: :ok
    end

    Some.bar()
    Some.bar(1)
    Some.bar(1, 2)
    """

    [
      %Location{type: :macro, file: file1, line: line1, column: column1},
      %Location{type: :macro, file: file2, line: line2, column: column2},
      %Location{type: :macro, file: nil, line: 3, column: 3}
    ] = Locator.implementations(buffer, 7, 7)

    assert file1 =~ "language_server/test/support/example_behaviour.ex"
    assert read_line(file1, {line1, column1}) =~ "defmacro bar(_b)"

    assert file2 =~ "language_server/test/support/example_behaviour.ex"
    assert read_line(file2, {line2, column2}) =~ "defmacro bar(_b)"

    # too little arguments

    [] = Locator.implementations(buffer, 6, 7)

    # too many arguments

    [] = Locator.implementations(buffer, 8, 7)
  end

  test "find implementation of delegated functions" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      MyMod.delegated_function()
      #        ^
    end
    """

    [%Location{type: :function, file: file, line: line, column: column}] =
      Locator.implementations(buffer, 3, 11)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "delegated_function do"
  end

  if Version.match?(System.version(), ">= 1.15.0") do
    test "find implementation of delegated functions in incomplete code" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
        MyMod.delegated_function(
        #        ^
      end
      """

      [%Location{type: :function, file: file, line: line, column: column}] =
        Locator.implementations(buffer, 3, 11)

      assert file =~ "language_server/test/support/module_with_functions.ex"
      assert read_line(file, {line, column}) =~ "delegated_function do"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
        MyMod.delegated_function(1
        #        ^
      end
      """

      [%Location{type: :function, file: file, line: line, column: column}] =
        Locator.implementations(buffer, 3, 11)

      assert file =~ "language_server/test/support/module_with_functions.ex"
      assert read_line(file, {line, column}) =~ "delegated_function(a) do"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
        MyMod.delegated_function(1,
        #        ^
      end
      """

      [%Location{type: :function, file: file, line: line, column: column}] =
        Locator.implementations(buffer, 3, 11)

      assert file =~ "language_server/test/support/module_with_functions.ex"
      assert read_line(file, {line, column}) =~ "delegated_function(a, b) do"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
        MyMod.delegated_function(1, 2,
        #        ^
      end
      """

      # too many arguments

      assert [] = Locator.implementations(buffer, 3, 11)
    end
  end

  test "find implementation of delegated functions via @attr" do
    buffer = """
    defmodule MyModule do
      @attr ElixirSenseExample.ModuleWithFunctions
      def a do
        @attr.delegated_function()
      end
    end
    """

    [%Location{type: :function, file: file, line: line, column: column}] =
      Locator.implementations(buffer, 4, 13)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "delegated_function do"
  end

  test "handle defdelegate" do
    buffer = """
    defmodule MyModule do
      defdelegate delegated_function, to: ElixirSenseExample.ModuleWithFunctions.DelegatedModule
      #            ^
    end
    """

    [%Location{type: :function, file: file, line: line, column: column}] =
      Locator.implementations(buffer, 2, 15)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "def delegated_function do"
  end

  test "handle defdelegate - navigate to correct arity" do
    buffer = """
    defmodule MyModule do
      defdelegate delegated_function(a), to: ElixirSenseExample.ModuleWithFunctions.DelegatedModule
      #            ^
    end
    """

    [%Location{type: :function, file: file, line: line, column: column}] =
      Locator.implementations(buffer, 2, 15)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "def delegated_function(a) do"
  end

  test "handle defdelegate - navigate to correct arity on default args" do
    buffer = """
    defmodule MyModule do
      defdelegate delegated_function(a \\\\ nil), to: ElixirSenseExample.ModuleWithFunctions.DelegatedModule
      #            ^
    end
    """

    [%Location{type: :function, file: file, line: line, column: column}] =
      Locator.implementations(buffer, 2, 15)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "def delegated_function(a) do"
  end

  test "handle defdelegate with `as`" do
    buffer = """
    defmodule MyModule do
      defdelegate my_function, to: ElixirSenseExample.ModuleWithFunctions.DelegatedModule, as: :delegated_function
      #            ^
    end
    """

    [%Location{type: :function, file: file, line: line, column: column}] =
      Locator.implementations(buffer, 2, 15)

    assert file =~ "language_server/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "delegated_function"
  end

  test "defdelegate to metadata module" do
    buffer = """
    defmodule SomeModWithDelegatee do
      def delegated_function, do: :ok
    end

    defmodule MyModule do
      defdelegate delegated_function, to: SomeModWithDelegatee
      #            ^
    end
    """

    assert [
             %Location{
               type: :function,
               file: nil,
               line: 2,
               column: 3,
               end_line: 2,
               end_column: 34
             }
           ] ==
             Locator.implementations(buffer, 6, 15)
  end

  test "handle recursion in defdelegate" do
    buffer = """
    defmodule MyModule do
      defdelegate delegated_function, to: MyModule
      #            ^
    end
    """

    assert [] == Locator.implementations(buffer, 2, 15)
  end

  defp read_line(file, {line, column}) do
    file
    |> File.read!()
    |> Source.split_lines()
    |> Enum.at(line - 1)
    |> String.slice((column - 1)..-1//1)
  end
end
