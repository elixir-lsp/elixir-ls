defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoDialyzerTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  use ElixirLS.LanguageServer.Protocol
  
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
      # Get the file URI for C module
      file_c = ElixirLS.LanguageServer.SourceFile.Path.to_uri(Path.absname("lib/suggest.ex"))
      
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
        did_open(file_c, "elixir", 1, File.read!(Path.absname("lib/suggest.ex")))
      )
      
      # Give dialyzer time to analyze the file
      Process.sleep(1000)

      # Get the server state which should have PLT loaded and contracts available
      state = :sys.get_state(server)

      # Now test our LlmTypeInfo command with module Suggest which has unspecced functions
      assert {:ok, result} = LlmTypeInfo.execute(["Suggest"], state)

      # Module Suggest should have dialyzer contracts for its unspecced function
      assert result.module == "Suggest"
      assert is_list(result.dialyzer_contracts |> dbg)
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
