defmodule ElixirLS.LanguageServer.Providers.Declaration.LocatorTest do
  use ExUnit.Case, async: true
  alias ElixirLS.LanguageServer.Providers.Declaration.Locator
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Source

  defp read_line(file, {line, column}) do
    file
    |> File.read!()
    |> Source.split_lines()
    |> Enum.at(line - 1)
    |> String.slice((column - 1)..-1//1)
  end

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

    # Since there is no callback declared in EmptyModule,
    # the declaration provider should return nil.
    assert nil == Locator.declaration(buffer, 2, 8)
  end

  test "return nil when cursor is not inside an implementation" do
    # For example, if the cursor is outside of any function definition,
    # there is no callback declaration to jump to.
    buffer = """
    defmodule Some do
      def foo(), do: :ok
    end
    """

    assert nil == Locator.declaration(buffer, 1, 1)
  end

  test "return nil when function does not implement any callback" do
    # A module without any behaviour/callback relation.
    buffer = """
    defmodule Some do
      def foo(), do: :ok
    end
    """

    # Cursor inside the foo implementation should yield no declaration.
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

    # Place the cursor somewhere within the implementation of foo/0.
    location = Locator.declaration(buffer, 7, 7)
    assert %Location{} = location
    assert location.type == :callback

    # In our test code the callback is defined in the behaviour module.
    # In this in‑buffer example we don’t have a file name so file is nil.
    # But we can at least check that the line number is in the behaviour module
    # (i.e. in the first half of the buffer).
    assert location.line <= 3
  end

  test "find declaration for remote behaviour callback with impl" do
    buffer = """
    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithDoc
      @impl ElixirSenseExample.ExampleBehaviourWithDoc
      def foo(), do: :ok
    end
    """

    # Place the cursor somewhere within the implementation of foo/0.
    location = Locator.declaration(buffer, 4, 7)
    assert %Location{} = location
    assert location.type == :callback
    assert location.file =~ "support/example_behaviour.ex"

    # In our test code the callback is defined in the behaviour module.
    # In this in‑buffer example we don’t have a file name so file is nil.
    # But we can at least check that the line number is in the behaviour module
    # (i.e. in the first half of the buffer).
    assert location.line == 213
  end

  test "find declaration for remote behaviour callback" do
    buffer = """
    defmodule Some do
      @behaviour ElixirSenseExample.ExampleBehaviourWithDoc
      def foo(), do: :ok
    end
    """

    # Place the cursor somewhere within the implementation of foo/0.
    location = Locator.declaration(buffer, 3, 7)
    assert %Location{} = location
    assert location.type == :callback

    # In our test code the callback is defined in the behaviour module.
    # In this in‑buffer example we don’t have a file name so file is nil.
    # But we can at least check that the line number is in the behaviour module
    # (i.e. in the first half of the buffer).
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

    # Place the cursor inside the protocol implementation.
    location = Locator.declaration(buffer, 6, 7)
    assert %Location{} = location
    # The protocol function declaration (the callback) should be in the protocol module.
    # Since this is an in-buffer example, file is nil.
    # We check that the declaration is on one of the first few lines.
    assert location.line <= 3
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
    # The protocol specification should be defined in the protocol section.
    assert location.line <= 3
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
    # The protocol specification should be defined in the protocol section.
    assert location.line == 2
  end
end
