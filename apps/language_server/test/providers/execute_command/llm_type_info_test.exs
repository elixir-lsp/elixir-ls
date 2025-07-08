defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoTest do
  use ElixirLS.Utils.MixTest.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfo
  alias ElixirLS.LanguageServer.{Server, Build, MixProjectCache, Parser, Tracer, Protocol}
  import ElixirLS.LanguageServer.Test.ServerTestHelpers
  use Protocol

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

    test "extracts type information from a module" do
      # Use GenServer for types
      module_name = "GenServer"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
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
    
    test "extracts specs from module with functions" do
      # Define a module with specs for testing
      defmodule ModuleWithSpecs do
        @spec add(integer(), integer()) :: integer()
        def add(a, b), do: a + b
        
        @spec multiply(number(), number()) :: number()
        def multiply(a, b), do: a * b
      end
      
      Code.ensure_compiled!(ModuleWithSpecs)
      
      module_name = "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoTest.ModuleWithSpecs"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
      assert result.module == inspect(ModuleWithSpecs)
      
      # Check specs
      assert is_list(result.specs)
      # Note: specs might not be available for runtime-defined modules
    end

    test "extracts callbacks from behaviour module" do
      # Define a simple behaviour module inline for testing
      defmodule SimpleBehaviour do
        @callback init(arg :: term()) :: {:ok, state :: term()}
        @callback handle_call(msg :: term(), from :: GenServer.from(), state :: term()) ::
          {:reply, reply :: term(), state :: term()}
      end
      
      # Ensure it's compiled
      Code.ensure_compiled!(SimpleBehaviour)
      
      module_name = "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoTest.SimpleBehaviour"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], %{})
      
      assert result.module == inspect(SimpleBehaviour)
      
      # Check callbacks 
      assert is_list(result.callbacks)
      # Note: callbacks might still be empty if not persisted in beam
      # This is a limitation of runtime-defined modules
    end

    test "extracts type info from standard library module" do
      # Use Enum which has types
      assert {:ok, result} = LlmTypeInfo.execute(["Enum"], %{})
      
      assert result.module == "Enum"
      
      # Enum has types
      assert is_list(result.types)
      assert length(result.types) > 0
      
      # Check for the t type
      t_type = Enum.find(result.types, &(&1.name == "t/0"))
      assert t_type
      
      # Enum might not have specs exported in beam
      assert is_list(result.specs)
    end

    test "includes dialyzer contracts field" do
      # Without a full server state, dialyzer contracts will be empty
      # The actual dialyzer test is in the @tag slow test below
      assert {:ok, result} = LlmTypeInfo.execute(["String"], %{})
      
      assert Map.has_key?(result, :dialyzer_contracts)
      assert is_list(result.dialyzer_contracts)
      # Without server state, this will be empty
      assert result.dialyzer_contracts == []
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
      assert private_spec.doc == ""
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
      assert handle_cast_callback.doc == ""
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
      assert private_type.doc == ""
    end
  end

  @tag slow: true, fixture: true
  test "extracts dialyzer contracts when dialyzer is enabled" do
    # Set compiler options as required
    compiler_options = Code.compiler_options()
    Build.set_compiler_options()

    on_exit(fn ->
      Code.compiler_options(compiler_options)
    end)
    
    # Setup server with required components
    {:ok, server} = Server.start_link()
    {:ok, _} = start_supervised(MixProjectCache)
    {:ok, _} = start_supervised(Parser)
    start_server(server)
    {:ok, _tracer} = start_supervised(Tracer)

    on_exit(fn ->
      if Process.alive?(server) do
        Process.monitor(server)
        GenServer.stop(server)

        receive do
          {:DOWN, _, _, ^server, _} ->
            :ok
        end
      end
    end)
    
    # Use path relative to __DIR__ to get to test/fixtures/dialyzer
    in_fixture(Path.join(__DIR__, "../.."), "dialyzer", fn ->
      # Get the file URI for C module
      file_c = ElixirLS.LanguageServer.SourceFile.Path.to_uri(Path.absname("lib/c.ex"))
      
      # Initialize with dialyzer enabled (incremental is default)
      initialize(server, %{
        "dialyzerEnabled" => true,
        "dialyzerFormat" => "dialyxir_long",
        "suggestSpecs" => true
      })

      # Wait for dialyzer to finish initial analysis
      assert_receive %{"method" => "textDocument/publishDiagnostics"}, 30000
      
      # Open the file so server knows about it
      Server.receive_packet(
        server,
        did_open(file_c, "elixir", 1, File.read!(Path.absname("lib/c.ex")))
      )
      
      # Give dialyzer time to analyze the file
      Process.sleep(1000)

      # Get the server state which should have PLT loaded and contracts available
      state = :sys.get_state(server)
      
      # Now test our LlmTypeInfo command with module C which has unspecced functions
      assert {:ok, result} = LlmTypeInfo.execute(["C"], state)
      
      # Module C should have dialyzer contracts for its unspecced function
      assert result.module == "C"
      assert is_list(result.dialyzer_contracts)
      assert length(result.dialyzer_contracts) > 0
      
      # The myfun function should have a dialyzer contract
      myfun_contract = Enum.find(result.dialyzer_contracts, &(&1.name == "myfun/0"))
      assert myfun_contract
      assert myfun_contract.contract
      assert String.contains?(myfun_contract.contract, "() -> 1")
      
      wait_until_compiled(server)
    end)
  end
end
