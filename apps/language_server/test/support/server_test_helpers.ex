defmodule ElixirLS.LanguageServer.Test.ServerTestHelpers do
  import ExUnit.Callbacks, only: [start_supervised!: 1]
  alias ElixirLS.LanguageServer.Server
  alias ElixirLS.Utils.PacketCapture

  def start_server do
    server = start_supervised!({Server, nil})
    packet_capture = start_supervised!({PacketCapture, self()})
    Process.group_leader(server, packet_capture)

    Process.whereis(ElixirLS.LanguageServer.Providers.WorkspaceSymbols)
    |> Process.group_leader(packet_capture)

    server
  end
end
