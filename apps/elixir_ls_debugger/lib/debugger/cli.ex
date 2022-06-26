defmodule ElixirLS.Debugger.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.Debugger.{Output, Server}

  def main do
    WireProtocol.intercept_output(&Output.print/1, &Output.print_err/1)
    Launch.start_mix()
    {:ok, _} = Application.ensure_all_started(:elixir_ls_debugger, :permanent)

    IO.puts("Started ElixirLS debugger v#{Launch.debugger_version()}")
    Launch.print_versions()
    Launch.limit_num_schedulers()
    warn_if_unsupported_version()
    WireProtocol.stream_packets(&Server.receive_packet/1)
  end

  defp warn_if_unsupported_version do
    with {:error, message} <- ElixirLS.Utils.MinimumVersion.check_elixir_version() do
      Output.print_err("WARNING: " <> message)
    end

    with {:error, message} <- ElixirLS.Utils.MinimumVersion.check_otp_version() do
      Output.print_err("WARNING: " <> message)
    end
  end
end
