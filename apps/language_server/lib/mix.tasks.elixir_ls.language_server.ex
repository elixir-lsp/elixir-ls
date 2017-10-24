defmodule Mix.Tasks.ElixirLs.LanguageServer do
  alias ElixirLS.Utils.WireProtocol
  alias ElixirLS.LanguageServer.JsonRpc

  def run(_args) do
    WireProtocol.intercept_output(&JsonRpc.print/1, &JsonRpc.print_err/1)
    Application.ensure_all_started(:language_server, :permanent)
    Mix.shell(ElixirLS.LanguageServer.MixShell)
    WireProtocol.stream_packets(&JsonRpc.receive_packet/1)
  end
end
