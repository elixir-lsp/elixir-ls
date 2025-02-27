defmodule ElixirLS.LanguageServer.Providers.Declaration.LocatorTest do
  use ExUnit.Case, async: true
  alias ElixirLS.LanguageServer.Providers.Declaration.Locator
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Source

  test "don't crash on empty buffer" do
    assert nil == Locator.declaration("", 1, 1)
  end

  test "don't error on __MODULE__ when no module" do
    assert nil == Locator.declaration("__MODULE__", 1, 1)
  end

  test "don't error on Elixir" do
    assert nil == Locator.declaration("Elixir", 1, 1)
  end

  test "don't error on not existing module" do
    assert nil == Locator.declaration("SomeNotExistingMod", 1, 1)
  end

  test "don't return declaration for non-behaviour module" do
    buffer = """
    defmodule ElixirSenseExample.EmptyModule do
      def abc(), do: :ok
    end
    """

    assert nil == Locator.declaration(buffer, 2, 8)
  end

  test "find declaration for behaviour callback" do
    buffer = """
    defmodule ElixirSenseExample.ExampleBehaviourWithCallback do
      @callback foo() :: :ok
    end

    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithCallback
      def foo(), do: :ok
    end
    """

    location = Locator.declaration(buffer, 7, 7)
    assert %Location{} = location
    assert location.type == :callback
    assert location.line == 2
  end

  test "find declaration for behaviour callback when cursor on callback" do
    buffer = """
    defmodule ElixirSenseExample.ExampleBehaviourWithCallback do
      @callback foo() :: :ok
    end
    """

    location = Locator.declaration(buffer, 2, 14)
    assert %Location{} = location
    assert location.type == :callback
    assert location.line == 2
  end

  test "find declaration for remote behaviour callback with impl" do
    buffer = """
    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithDoc
      @impl ElixirSenseExample.ExampleBehaviourWithDoc
      def foo(), do: :ok
    end
    """

    location = Locator.declaration(buffer, 4, 7)
    assert %Location{} = location
    assert location.type == :callback
    assert location.file =~ "support/example_behaviour.ex"
    assert location.line == 213
    assert read_range(location) =~ "@callback foo()"
  end

  test "find declaration for behaviour callback when cursor on call" do
    buffer = """
    defmodule ElixirSenseExample.ExampleBehaviourWithCallback do
      @callback foo() :: :ok
    end

    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithCallback
      def foo(), do: :ok
    end

    Some.foo()
    """

    location = Locator.declaration(buffer, 10, 7)
    assert %Location{} = location
    assert location.type == :callback
    assert location.line == 2
  end

  test "find declaration for remote behaviour callback" do
    buffer = """
    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithDoc
      def foo(), do: :ok
    end
    """

    location = Locator.declaration(buffer, 3, 7)
    assert %Location{} = location
    assert location.type == :callback
    assert location.line == 213
  end

  test "find declaration for protocol function" do
    buffer = """
    defprotocol ElixirSenseExample.ExampleProtocol do
      def some(t)
    end

    defimpl ElixirSenseExample.ExampleProtocol, for: String do
      def some(t), do: t
    end
    """

    location = Locator.declaration(buffer, 6, 7)
    assert %Location{} = location
    assert location.line == 2
  end

  test "find declaration for protocol function when cursor on call" do
    buffer = """
    defprotocol ElixirSenseExample.ExampleProtocol do
      def some(t)
    end

    defimpl ElixirSenseExample.ExampleProtocol, for: String do
      def some(t), do: t
    end

    ElixirSenseExample.ExampleProtocol.String.some("foo")
    """

    location = Locator.declaration(buffer, 9, 44)
    assert %Location{} = location
    assert location.line == 2
  end

  test "find declaration for protocol function with spec" do
    buffer = """
    defprotocol ElixirSenseExample.AnotherProtocol do
      @spec bar(t) :: any
      def bar(t)
    end

    defimpl ElixirSenseExample.AnotherProtocol, for: List do
      def bar(t), do: t
    end
    """

    location = Locator.declaration(buffer, 7, 7)
    assert %Location{} = location
    assert location.line == 2
  end

  test "find declaration for protocol function when cursor on def" do
    buffer = """
    defprotocol ElixirSenseExample.ExampleProtocol do
      def some(t)
    end
    """

    location = Locator.declaration(buffer, 2, 8)
    assert %Location{} = location
    assert location.line == 2
  end

  test "find declaration for protocol function when cursor on spec" do
    buffer = """
    defprotocol ElixirSenseExample.ExampleProtocol do
      @spec some(t) :: any
      def some(t)
    end
    """

    location = Locator.declaration(buffer, 2, 10)
    assert %Location{} = location
    assert location.line == 2
  end

  test "find declaration for remote protocol function" do
    buffer = """
    defimpl ElixirSenseExample.ExampleProtocol, for: Atom do
      def some(t), do: t
    end
    """

    location = Locator.declaration(buffer, 2, 7)
    assert %Location{} = location

    assert location.file =~ "test/support/example_protocol.ex"
    assert location.line == 2
    assert read_range(location) =~ "@spec some"
  end

  test "chooses callback basing on arity" do
    buffer = """
    defmodule ElixirSenseExample.Behaviour1 do
      @callback foo(a) :: :ok
    end

    defmodule ElixirSenseExample.Behaviour2 do
      @callback foo(a, b) :: :ok
    end

    defmodule Some do
      @behaviour ElixirSenseExample.Behaviour1
      @behaviour ElixirSenseExample.Behaviour2

      def foo(a), do: :ok
    end
    """

    location = Locator.declaration(buffer, 13, 7)

    assert %Location{} = location
    assert location.line == 2
  end

  test "find declaration for overridable def" do
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

    location = Locator.declaration(buffer, 4, 8)
    assert %Location{} = location

    # point to __using__ macro
    assert location.file =~ "test/support/overridable_function.ex"
    assert location.line == 2

    assert read_range(location) =~ "defmacro __using__"
  end

  test "find declaration for overridable behaviour callback" do
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

    location = Locator.declaration(buffer, 4, 8)
    assert %Location{} = location

    # point to callback definition
    assert location.file =~ "test/support/overridable_function.ex"
    assert location.line == 19

    assert read_range(location) =~ "@callback foo"
  end

  defp read_range(
         %Location{line: line, column: column, end_line: line, end_column: column} = location
       ) do
    location.file
    |> File.read!()
    |> Source.split_lines()
    |> Enum.at(line - 1)
    |> String.slice((column - 1)..-1//1)
  end

  defp read_range(%Location{} = location) do
    text =
      location.file
      |> File.read!()

    [_, text_in_range, _] =
      Source.split_at(text, [
        {location.line, location.column},
        {location.end_line, location.end_column}
      ])

    text_in_range
  end
end
