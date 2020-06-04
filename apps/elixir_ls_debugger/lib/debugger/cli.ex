defmodule ElixirLS.Debugger.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.Debugger.{Output, Server}

  def main do
    WireProtocol.intercept_output(&Output.print/1, &Output.print_err/1)
    Launch.start_mix()
    Application.ensure_all_started(:elixir_ls_debugger, :permanent)
    IO.puts("Started ElixirLS debugger v#{Launch.debugger_version()}")
    Launch.print_versions()
    warn_if_unsupported_version()
    WireProtocol.stream_packets(&Server.receive_packet/1)
  end

  # Debugging does not work on Elixir 1.10.0-1.10.2:
  # https://github.com/elixir-lsp/elixir-ls/issues/158
  defp warn_if_unsupported_version do
    elixir_version = System.version()

    if Version.match?(elixir_version, ">= 1.10.0") && Version.match?(elixir_version, "< 1.10.3") do
      message =
        "WARNING: Debugging is not supported on Elixir #{elixir_version}. Please upgrade" <>
          " to at least 1.10.3\n" <>
          "more info: https://github.com/elixir-lsp/elixir-ls/issues/158"

      Output.print_err(message)
    end
  end
end
