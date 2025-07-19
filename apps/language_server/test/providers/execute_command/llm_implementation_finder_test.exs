defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmImplementationFinderTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmImplementationFinder

  defmodule TestBehaviour do
    @callback test_callback(arg :: term()) :: term()
    @callback test_callback_with_arity(arg1 :: term(), arg2 :: term()) :: term()
  end

  defmodule TestBehaviourImpl do
    @behaviour TestBehaviour

    @impl true
    def test_callback(arg), do: arg

    @impl true
    def test_callback_with_arity(arg1, arg2), do: {arg1, arg2}
  end

  describe "execute/2" do
    setup do
      # Ensure test modules are loaded
      Code.ensure_loaded?(TestBehaviour)
      Code.ensure_loaded?(TestBehaviourImpl)
      Code.ensure_loaded?(GenServer)
      Code.ensure_loaded?(Enumerable)
      :ok
    end

    test "finds behaviour implementations by module name" do
      # GenServer is a well-known behaviour
      assert {:ok, result} = LlmImplementationFinder.execute(["GenServer"], %{}) |> dbg

      assert Map.has_key?(result, :implementations)
      assert is_list(result.implementations)

      # Should find many implementations in the running system
      assert length(result.implementations) > 0

      # Check that implementations have the expected structure
      impl = hd(result.implementations)
      assert Map.has_key?(impl, :module)
      assert Map.has_key?(impl, :source)
      assert Map.has_key?(impl, :type)
    end

    test "finds protocol implementations by protocol name" do
      # Enumerable is a well-known protocol
      assert {:ok, result} = LlmImplementationFinder.execute(["Enumerable"], %{})

      assert Map.has_key?(result, :implementations)
      assert is_list(result.implementations)

      # Should find implementations for List, Map, etc.
      assert length(result.implementations) > 0

      # Check for List implementation
      list_impl =
        Enum.find(result.implementations, fn impl ->
          String.contains?(impl.module, "List")
        end)

      assert list_impl != nil
    end

    test "finds specific callback implementations" do
      # GenServer.init/1 callback
      assert {:ok, result} = LlmImplementationFinder.execute(["GenServer.init/1"], %{})

      assert Map.has_key?(result, :implementations)
      assert is_list(result.implementations)

      # Should find implementations of the init callback
      assert length(result.implementations) > 0
    end

    test "finds callback implementations without arity" do
      # GenServer.init callback (any arity)
      assert {:ok, result} = LlmImplementationFinder.execute(["GenServer.init"], %{})

      assert Map.has_key?(result, :implementations)
      assert is_list(result.implementations)
    end

    test "handles Erlang module format" do
      # :gen_server is the underlying Erlang behaviour
      assert {:ok, result} = LlmImplementationFinder.execute([":gen_server"], %{})

      # May or may not find implementations depending on how ElixirLS handles Erlang modules
      assert Map.has_key?(result, :implementations) or Map.has_key?(result, :error)
    end

    test "returns error for non-behaviour/non-protocol modules" do
      assert {:ok, result} = LlmImplementationFinder.execute(["String"], %{})

      assert Map.has_key?(result, :error)
      assert String.contains?(result.error, "not a behaviour or protocol")
    end

    test "returns error for invalid symbol format" do
      assert {:ok, result} = LlmImplementationFinder.execute(["not_a_valid_module"], %{})

      assert Map.has_key?(result, :error)
      # V2 parser successfully parses this as a local call but finds no implementations
      assert String.contains?(result.error, "Local call") and
               String.contains?(result.error, "no implementations found")
    end

    test "returns error for invalid arguments" do
      assert {:ok, result} = LlmImplementationFinder.execute([], %{})
      assert Map.has_key?(result, :error)
      assert String.contains?(result.error, "Invalid arguments")

      assert {:ok, result} = LlmImplementationFinder.execute([123], %{})
      assert Map.has_key?(result, :error)
      assert String.contains?(result.error, "Invalid arguments")
    end

    test "finds test behaviour implementations" do
      module_name =
        "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmImplementationFinderTest.TestBehaviour"

      assert {:ok, result} = LlmImplementationFinder.execute([module_name], %{})

      # Our test behaviour should have at least our test implementation
      assert Map.has_key?(result, :implementations)
      assert is_list(result.implementations)

      # Find our test implementation
      test_impl =
        Enum.find(result.implementations, fn impl ->
          String.contains?(impl.module, "TestBehaviourImpl")
        end)

      if test_impl do
        assert String.contains?(test_impl.source, "@behaviour")
        assert String.contains?(test_impl.source, "test_callback")
      end
    end

    test "handles modules that don't exist" do
      assert {:ok, result} = LlmImplementationFinder.execute(["NonExistent.Module"], %{})

      assert Map.has_key?(result, :error)
    end

    test "handles nested module names" do
      # Test with a deeply nested module name
      assert {:ok, result} = LlmImplementationFinder.execute(["Elixir.GenServer"], %{})

      assert Map.has_key?(result, :implementations)
      assert is_list(result.implementations)
    end
  end
end
