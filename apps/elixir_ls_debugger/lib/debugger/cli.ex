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

  # Debugging does not work on Elixir 1.10.0-1.10.2:
  # https://github.com/elixir-lsp/elixir-ls/issues/158
  defp warn_if_unsupported_version do
    elixir_version = System.version()

    unless Version.match?(elixir_version, ">= 1.8.0") do
      message =
        "WARNING: Elixir versions below 1.8 are not supported. (Currently v#{elixir_version})"

      Output.print_err(message)
    end

    if Version.match?(elixir_version, ">= 1.10.0") && Version.match?(elixir_version, "< 1.10.3") do
      message =
        "WARNING: Debugging is not supported on Elixir #{elixir_version}. Please upgrade" <>
          " to at least 1.10.3\n" <>
          "more info: https://github.com/elixir-lsp/elixir-ls/issues/158"

      Output.print_err(message)
    end

    otp_release = String.to_integer(System.otp_release())

    if otp_release < 21 do
      message =
        "WARNING: Erlang OTP releases below 21 are not supported (Currently OTP #{otp_release})"

      Output.print_err(message)
    end
  end
end
