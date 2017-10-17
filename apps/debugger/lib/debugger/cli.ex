defmodule ElixirLS.Debugger.CLI do
  alias ElixirLS.Utils.WireProtocol
  alias ElixirLS.Debugger.{Output, Server}

  def main(_args) do
    WireProtocol.intercept_output(&Output.print/1, &Output.print_err/1)

    Application.ensure_all_started(:elixir_ls_debugger, :permanent)

    Mix.Local.append_archives
    Mix.Local.append_paths

    WireProtocol.stream_packets(&Server.receive_packet/1)
  end
end
