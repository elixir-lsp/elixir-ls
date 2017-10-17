defmodule ElixirLS.LanguageServer.CLI do
  alias ElixirLS.Utils.WireProtocol
  alias ElixirLS.LanguageServer.JsonRpc

  def main(_args) do
    WireProtocol.intercept_output(&JsonRpc.print/1, &JsonRpc.print_err/1)

    Application.ensure_all_started(:language_server, :permanent)

    Mix.Local.append_archives
    Mix.Local.append_paths

    Mix.shell(ElixirLS.LanguageServer.MixShell)

    WireProtocol.stream_packets(&JsonRpc.receive_packet/1)
  end
end
