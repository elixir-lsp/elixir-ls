defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoDialyzerTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  
  alias ElixirLS.LanguageServer.{Server, Build, MixProjectCache, Parser, Tracer}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfo
  import ElixirLS.LanguageServer.Test.ServerTestHelpers

  setup_all do
    compiler_options = Code.compiler_options()
    Build.set_compiler_options()

    on_exit(fn ->
      Code.compiler_options(compiler_options)
    end)

    {:ok, %{}}
  end

  setup do
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

    {:ok, %{server: server}}
  end

  @tag :slow
  @tag :fixture
  test "includes dialyzer contracts when PLT is available", %{server: server} do
    in_fixture(Path.join(__DIR__, "../.."), "dialyzer", fn ->
      # Initialize with dialyzer enabled
      initialize(server, %{"dialyzerEnabled" => true})
      
      # Wait for dialyzer to finish
      assert_receive %{"method" => "textDocument/publishDiagnostics"}, 30000
      
      # Get the server state (which should have PLT loaded)
      state = :sys.get_state(server)
      
      # Compile the fixture module
      fixture_path = Path.join(__DIR__, "../../support/llm_type_info_fixture.ex")
      Code.compile_file(fixture_path)
      
      # Now test with the actual state that has PLT
      module_name = "ElixirLS.Test.LlmTypeInfoFixture.SimpleModule"
      
      assert {:ok, result} = LlmTypeInfo.execute([module_name], state)
      
      # Should have dialyzer contracts for unspecced functions
      assert is_list(result.dialyzer_contracts)
      
      # The identity function should have a contract
      if length(result.dialyzer_contracts) > 0 do
        identity_contract = Enum.find(result.dialyzer_contracts, &(&1.name == "identity/1"))
        assert identity_contract
        assert identity_contract.contract
      end
    end)
  end
end