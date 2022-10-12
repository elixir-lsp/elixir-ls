defmodule ElixirLS.Debugger.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.Debugger.{Output, Server}

  def main do
    WireProtocol.intercept_output(&Output.debuggee_out/1, &Output.debuggee_err/1)
    Launch.start_mix()
    {:ok, _} = Application.ensure_all_started(:elixir_ls_debugger, :permanent)

    Output.debugger_console("Started ElixirLS Debugger v#{Launch.debugger_version()}")
    versions = Launch.get_versions()

    Output.debugger_console(
      "ElixirLS Debugger built with elixir #{versions.compile_elixir_version} on OTP #{versions.compile_otp_version}"
    )

    Output.debugger_console(
      "Running on elixir #{versions.current_elixir_version} on OTP #{versions.current_otp_version}"
    )

    Launch.limit_num_schedulers()
    warn_if_unsupported_version()
    WireProtocol.stream_packets(&Server.receive_packet/1)
  end

  defp warn_if_unsupported_version do
    with {:error, message} <- ElixirLS.Utils.MinimumVersion.check_elixir_version() do
      Output.debugger_important("WARNING: " <> message)
    end

    with {:error, message} <- ElixirLS.Utils.MinimumVersion.check_otp_version() do
      Output.debugger_important("WARNING: " <> message)
    end
  end
end
