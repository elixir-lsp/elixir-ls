defmodule Mix.Tasks.ElixirLs.Debugger do
  alias ElixirLS.Utils.WireProtocol
  alias ElixirLS.Debugger.{Output, Server}

  def run(_args) do
    WireProtocol.intercept_output(&Output.print/1, &Output.print_err/1)
    ElixirLS.Utils.Launch.restore_mix_exs_var()
    Application.ensure_all_started(:debugger, :permanent)
    IO.puts("Started ElixirLS debugger")
    WireProtocol.stream_packets(&Server.receive_packet/1)
  end
end
