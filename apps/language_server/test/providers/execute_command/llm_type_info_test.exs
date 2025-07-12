defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoTest do
  use ElixirLS.Utils.MixTest.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfo

  defmodule TestBehaviour do
    @moduledoc """
    Test behaviour for type info extraction.
    """

    @doc """
    Callback to test extraction.
    """
    @callback process(data :: term()) :: {:ok, term()} | {:error, String.t()}

    @doc """
    Another callback with multiple clauses.
    """
    @callback handle_event(event :: atom(), state :: term()) :: {:ok, term()}
  end

  defmodule TestModule do
    @moduledoc """
    Test module for type information extraction.
    """

    @behaviour TestBehaviour

    @typedoc """
    A public type representing a user.
    """
    @type user :: %{
      name: String.t(),
      age: non_neg_integer(),
      email: String.t()
    }

    @typedoc """
    An opaque type for internal ID representation.
    """
    @opaque id :: binary()

    @type status :: :active | :inactive | :pending

    @doc """
    Creates a new user.
    """
    @spec create_user(String.t(), non_neg_integer()) :: user()
    def create_user(name, age) do
      %{name: name, age: age, email: "#{name}@example.com"}
    end

    @doc """
    Gets user by ID.
    """
    @spec get_user(id()) :: {:ok, user()} | {:error, :not_found}
    def get_user(_id) do
      {:ok, %{name: "Test", age: 30, email: "test@example.com"}}
    end

    @spec process_data(term()) :: term()
    def process_data(data), do: data

    # Implementing behaviour callbacks
    @impl true
    def process(data), do: {:ok, data}

    @impl true
    def handle_event(_event, state), do: {:ok, state}
  end

  describe "execute/2" do
    setup do
      # Ensure test modules are loaded
      Code.ensure_loaded?(TestModule)
      Code.ensure_loaded?(TestBehaviour)
      Code.ensure_loaded?(GenServer)
      :ok
    end

    test "extracts type information from a standard library module" do
      # Use GenServer for types
      module_name = "GenServer"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})

      dbg(result)
      
      assert result.module == "GenServer"
      
      # Check types
      assert is_list(result.types)
      # GenServer module has types like from, server, etc.
      assert length(result.types) > 0
      
      # Find a known type in GenServer
      from_type = Enum.find(result.types, &(&1.name == "from/0"))
      assert from_type
      assert from_type.kind == :type
      assert from_type.spec
      assert from_type.signature
    end

    test "extracts type information from a module" do
      # Use ElixirLS.Test.WithTypes for types
      module_name = "ElixirLS.Test.WithTypes"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})

      dbg(result)
      
      assert result.module == "ElixirLS.Test.WithTypes"
      
      # Check types
      assert is_list(result.types) and length(result.types) > 0
      assert %{
        name: "no_arg/0",
        signature: "no_arg()",
        spec: "@type no_arg() :: :ok",
        kind: :type
      } in result.types

      assert %{
        name: "one_arg/1",
        signature: "one_arg(t)",
        spec: "@type one_arg(t) :: {:ok, t}",
        kind: :type
      } in result.types

      assert %{
        name: "one_arg_named/1",
        signature: "one_arg_named(t)",
        spec: "@type one_arg_named(t) :: {:ok, t, bar :: integer()}",
        kind: :type
      } in result.types

      # opaque type has definition hidden
      assert %{
        name: "opaque_type/0",
        signature: "opaque_type()",
        spec: "@opaque opaque_type()",
        kind: :opaque
      } in result.types

      # private type should not be included
      refute Enum.any?(result.types, &(&1.name == "private_type/0"))

      # Check specs
      assert is_list(result.specs) and length(result.specs) > 0

      # functions
      
      assert %{name: "no_arg/0", specs: "@spec no_arg() :: :ok"} in result.specs
      assert %{name: "one_arg/1", specs: "@spec one_arg(term()) :: {:ok, term()}"} in result.specs
      assert %{
        name: "one_arg_named/2",
        specs: "@spec one_arg_named(foo :: term(), bar :: integer()) :: {:ok, term(), baz :: integer()}"
      } in result.specs
      assert %{
        name: "multiple_specs/2",
        specs: "@spec multiple_specs(term(), integer()) :: {:ok, term(), integer()}\n@spec multiple_specs(term(), float()) :: {:ok, term(), float()}"
      } in result.specs
      assert %{
        name: "bounded_fun/1",
        specs: "@spec bounded_fun(foo) :: {:ok, term()} when foo: term()"
      } in result.specs

      # macros
      assert %{name: "macro/1", specs: "@spec macro(Macro.t()) :: Macro.t()"} in result.specs
      assert %{
        name: "macro_bounded/1",
        specs: "@spec macro_bounded(foo) :: Macro.t() when foo: term()"
      } in result.specs

      # Check callbacks
      assert is_list(result.callbacks) and length(result.callbacks) > 0

      # callbacks
      
      assert %{name: "callback_no_arg/0", specs: "@callback callback_no_arg() :: :ok"} in result.callbacks
      assert %{
        name: "callback_one_arg/1",
        specs: "@callback callback_one_arg(term()) :: {:ok, term()}"
      } in result.callbacks
      assert %{
        name: "callback_one_arg_named/2",
        specs: "@callback callback_one_arg_named(foo :: term(), bar :: integer()) :: {:ok, term(), baz :: integer()}"
      } in result.callbacks
      assert %{
        name: "callback_multiple_specs/2",
        specs: "@callback callback_multiple_specs(term(), integer()) :: {:ok, term(), integer()}\n@callback callback_multiple_specs(term(), float()) :: {:ok, term(), float()}"
      } in result.callbacks
      assert %{
        name: "callback_bounded_fun/1",
        specs: "@callback callback_bounded_fun(foo) :: {:ok, term()} when foo: term()"
      } in result.callbacks
      # macrocallbacks
      assert %{
        name: "callback_macro/1",
        specs: "@macrocallback callback_macro(Macro.t()) :: Macro.t()"
      } in result.callbacks
      assert %{
        name: "callback_macro_bounded/1",
        specs: "@macrocallback callback_macro_bounded(foo) :: Macro.t() when foo: term()"
      } in result.callbacks
    end

    test "extracts type information from mfa" do
      # try type or spec
      mfa = "ElixirLS.Test.WithTypes.multiple_arities/1"

      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{
        name: "multiple_arities/1",
        signature: "multiple_arities(t)",
        spec: "@type multiple_arities(t) :: {:ok, t}",
        kind: :type
      } in result.types

      assert %{name: "multiple_arities/1", specs: "@spec multiple_arities(arg1 :: term()) :: {:ok, term()}"} in result.specs
      refute Enum.any?(result.types, &(&1.name == "one_arg/1"))
      refute Enum.any?(result.types, &(&1.name == "multiple_arities/2"))

      refute Enum.any?(result.specs, &(&1.name == "one_arg/1"))
      refute Enum.any?(result.specs, &(&1.name == "multiple_arities/2"))

      # try macro spec
      mfa = "ElixirLS.Test.WithTypes.macro/1"

      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{name: "macro/1", specs: "@spec macro(Macro.t()) :: Macro.t()"} in result.specs
      refute Enum.any?(result.specs, &(&1.name == "one_arg/1"))

      # try callback
      mfa = "ElixirLS.Test.WithTypes.callback_multiple_arities/1"
      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{name: "callback_multiple_arities/1", specs: "@callback callback_multiple_arities(arg1 :: term()) :: {:ok, term()}"} in result.callbacks
      refute Enum.any?(result.callbacks, &(&1.name == "one_arg/1"))
      refute Enum.any?(result.callbacks, &(&1.name == "multiple_arities/2"))

      # try macrocallback
      mfa = "ElixirLS.Test.WithTypes.callback_macro/1"
      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{name: "callback_macro/1", specs: "@macrocallback callback_macro(Macro.t()) :: Macro.t()"} in result.callbacks
    end

    test "extracts type information from mf" do
      # try type or spec
      mfa = "ElixirLS.Test.WithTypes.multiple_arities"

      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{
        name: "multiple_arities/1",
        signature: "multiple_arities(t)",
        spec: "@type multiple_arities(t) :: {:ok, t}",
        kind: :type
      } in result.types

      assert %{name: "multiple_arities/1", specs: "@spec multiple_arities(arg1 :: term()) :: {:ok, term()}"} in result.specs
      refute Enum.any?(result.types, &(&1.name == "one_arg/1"))
      assert Enum.any?(result.types, &(&1.name == "multiple_arities/2"))

      refute Enum.any?(result.specs, &(&1.name == "one_arg/1"))
      assert Enum.any?(result.specs, &(&1.name == "multiple_arities/2"))

      # try macro spec
      mfa = "ElixirLS.Test.WithTypes.macro"

      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{name: "macro/1", specs: "@spec macro(Macro.t()) :: Macro.t()"} in result.specs

      # try callback
      mfa = "ElixirLS.Test.WithTypes.callback_multiple_arities"
      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{name: "callback_multiple_arities/1", specs: "@callback callback_multiple_arities(arg1 :: term()) :: {:ok, term()}"} in result.callbacks
      refute Enum.any?(result.callbacks, &(&1.name == "one_arg/1"))
      assert Enum.any?(result.callbacks, &(&1.name == "callback_multiple_arities/2"))

      # try macrocallback
      mfa = "ElixirLS.Test.WithTypes.callback_macro"
      assert {:ok, result} = LlmTypeInfo.execute([mfa], %{})

      assert %{name: "callback_macro/1", specs: "@macrocallback callback_macro(Macro.t()) :: Macro.t()"} in result.callbacks
    end

    test "handles module not found" do
      assert {:ok, result} = LlmTypeInfo.execute(["NonExistentModule"], %{})
      
      assert Map.has_key?(result, :error)
      assert String.contains?(result.error, "Module not found")
    end

    test "handles invalid arguments" do
      assert {:ok, result} = LlmTypeInfo.execute([], %{})
      assert Map.has_key?(result, :error)
      assert String.contains?(result.error, "Invalid arguments")
      
      assert {:ok, result} = LlmTypeInfo.execute([123], %{})
      assert Map.has_key?(result, :error)
      assert String.contains?(result.error, "Invalid arguments")
    end

    test "handles modules without types or specs" do
      defmodule EmptyModule do
        def hello, do: :world
      end
      
      module_name = "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoTest.EmptyModule"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
      assert result.module == inspect(EmptyModule)
      assert result.types == []
      assert result.specs == []
      assert result.callbacks == []
    end

    test "formats type signatures correctly" do
      # Use GenServer which we know has types
      module_name = "GenServer"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
      # Check that signatures are properly formatted
      from_type = Enum.find(result.types, &(&1.name == "from/0"))
      assert from_type
      assert from_type.signature == "from()"
      assert from_type.spec
      assert String.contains?(from_type.spec, "@type from()")
    end
  end

  describe "fixture modules" do
    setup do
      # Compile fixture module if not already done
      fixture_path = Path.join(__DIR__, "../../support/llm_type_info_fixture.ex")
      Code.compile_file(fixture_path)
      :ok
    end

    test "extracts specs from compiled module" do
      module_name = "ElixirLS.Test.LlmTypeInfoFixture.Implementation"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
      assert result.module == module_name
      
      # Check that we have specs
      assert is_list(result.specs)
      assert length(result.specs) > 0
      
      # Find create_user spec
      create_user_spec = Enum.find(result.specs, &(&1.name == "create_user/2"))
      assert create_user_spec
      assert String.contains?(create_user_spec.specs, "@spec create_user(String.t(), non_neg_integer()) :: user()")
      
      # Find get_status spec
      get_status_spec = Enum.find(result.specs, &(&1.name == "get_status/1"))
      assert get_status_spec
      assert String.contains?(get_status_spec.specs, "@spec get_status(user()) :: status()")
      
      # Private function should not have docs
      private_spec = Enum.find(result.specs, &(&1.name == "private_fun/1"))
      assert private_spec
    end

    test "extracts callbacks from behaviour module" do
      module_name = "ElixirLS.Test.LlmTypeInfoFixture.TestBehaviour"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
      assert result.module == module_name
      
      # Check callbacks
      assert is_list(result.callbacks)
      assert length(result.callbacks) > 0
      
      # Find init callback
      init_callback = Enum.find(result.callbacks, &(&1.name == "init/1"))
      assert init_callback
      assert String.contains?(init_callback.specs, "@callback init(args :: term()) ::")
      
      # Find handle_call callback
      handle_call_callback = Enum.find(result.callbacks, &(&1.name == "handle_call/3"))
      assert handle_call_callback
      assert String.contains?(handle_call_callback.specs, "@callback handle_call")
      
      # handle_cast should be there but without docs
      handle_cast_callback = Enum.find(result.callbacks, &(&1.name == "handle_cast/2"))
      assert handle_cast_callback
    end

    test "extracts all type information from implementation module" do
      module_name = "ElixirLS.Test.LlmTypeInfoFixture.Implementation"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
      # Check types
      assert length(result.types) > 0
      
      user_type = Enum.find(result.types, &(&1.name == "user/0"))
      assert user_type
      assert user_type.kind == :type
      
      status_type = Enum.find(result.types, &(&1.name == "status/0"))
      assert status_type
      assert String.contains?(status_type.spec, ":active | :inactive | :pending")
      
      token_type = Enum.find(result.types, &(&1.name == "token/0"))
      assert token_type
      assert token_type.kind == :opaque
      
      # private_type should not be included (has @typedoc false)
      private_type = Enum.find(result.types, &(&1.name == "private_type/0"))
      assert private_type
    end
  end
end
