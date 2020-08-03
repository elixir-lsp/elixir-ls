defmodule ElixirLS.LanguageServer.Test.ServerTestHelpers do
  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias ElixirLS.LanguageServer.Server
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols
  alias ElixirLS.Utils.PacketCapture

  def start_server(opts \\ []) do
    packet_capture = start_supervised!({PacketCapture, self()})

    server = start_supervised!({Server, opts})
    Process.group_leader(server, packet_capture)

    json_rpc = start_supervised!({JsonRpc, name: JsonRpc})
    Process.group_leader(json_rpc, packet_capture)

    workspace_symbols = start_supervised!({WorkspaceSymbols, []})
    Process.group_leader(workspace_symbols, packet_capture)

    server
  end

  def assert_server_does_not_crash(server) do
    Task.start_link(fn ->
      ref = Process.monitor(server)

      receive do
        {:DOWN, ^ref, :process, _object, :normal} ->
          nil

        {:DOWN, ^ref, :process, _object, reason} ->
          ExUnit.Assertions.flunk("""
          Server should not crash.

          Crashed with:
          #{inspect(reason, pretty: true)}
          """)
      end
    end)

  end
end
