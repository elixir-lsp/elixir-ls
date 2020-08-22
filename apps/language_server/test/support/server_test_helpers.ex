defmodule ElixirLS.LanguageServer.Test.ServerTestHelpers do
  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias ElixirLS.LanguageServer.Server
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols
  alias ElixirLS.Utils.PacketCapture

  def start_server do
    packet_capture = start_supervised!({PacketCapture, self()})

    server = start_supervised!({Server, nil})
    IO.puts(:user, "\nStarted server: #{inspect(server)}")
    Process.group_leader(server, packet_capture)

    json_rpc = start_supervised!({JsonRpc, name: JsonRpc})
    Process.group_leader(json_rpc, packet_capture)

    workspace_symbols = start_supervised!({WorkspaceSymbols, []})
    Process.group_leader(workspace_symbols, packet_capture)

    server
  end
end
