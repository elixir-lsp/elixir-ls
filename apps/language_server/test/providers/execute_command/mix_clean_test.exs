defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.MixCleanTest do
  alias ElixirLS.LanguageServer.{Server, Protocol, SourceFile}
  use ElixirLS.Utils.MixTest.Case, async: false
  use Protocol

  setup do
    server = ElixirLS.LanguageServer.Test.ServerTestHelpers.start_server()

    {:ok, %{server: server}}
  end

  @tag fixture: true
  test "mix clean", %{server: server} do
    in_fixture(Path.join(__DIR__, "../.."), "clean", fn ->
      root_uri = SourceFile.path_to_uri(File.cwd!())
      Server.receive_packet(server, initialize_req(1, root_uri, %{}))

      Server.receive_packet(
        server,
        did_change_configuration(%{
          "elixirLS" => %{}
        })
      )

      assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000
      path = ".elixir_ls/build/test/lib/els_clean_test/ebin/Elixir.A.beam"
      assert File.exists?(path)

      server_instance_id = :sys.get_state(server).server_instance_id

      Server.receive_packet(
        server,
        execute_command_req(4, "mixClean:#{server_instance_id}", [false])
      )

      res = assert_receive(%{"id" => 4}, 5000)
      assert res["result"] == %{}

      refute File.exists?(path)
    end)
  end
end
