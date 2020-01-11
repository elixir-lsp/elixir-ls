defmodule ElixirLS.LanguageServer.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.LanguageServer.JsonRpc

  def main do
    WireProtocol.intercept_output(&JsonRpc.print/1, &JsonRpc.print_err/1)
    Launch.start_mix()

    Application.ensure_all_started(:language_server, :temporary)
    IO.puts("Started ElixirLS Fork v#{Launch.language_server_version()}")
    Launch.print_versions()

    Mix.shell(ElixirLS.LanguageServer.MixShell)
    # FIXME: Private API
    Mix.Hex.ensure_updated?()

    WireProtocol.stream_packets(&JsonRpc.receive_packet/1)
  end
end
