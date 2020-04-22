defmodule ElixirLS.Debugger.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.Debugger.{Output, Server}

  def main do
    WireProtocol.intercept_output(&Output.print/1, &Output.print_err/1)
    Launch.start_mix()
    Application.ensure_all_started(:debugger, :permanent)
    IO.puts("Started ElixirLS debugger v#{Launch.debugger_version()}")
    Launch.print_versions()
    WireProtocol.stream_packets(&Server.receive_packet/1)
  end
end
