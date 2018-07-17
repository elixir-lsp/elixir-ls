defmodule ElixirLS.LanguageServer.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.LanguageServer.JsonRpc

  def main do
    WireProtocol.intercept_output(&JsonRpc.print/1, &JsonRpc.print_err/1)
    Launch.start_mix()

    # TODO: Figure out a safe way to use the custom logger backend in Elixir 1.7
    unless Version.match?(System.version(), ">= 1.7.0-dev") do
      configure_logger()
    end

    Application.ensure_all_started(:language_server, :temporary)
    IO.puts("Started ElixirLS")

    Mix.shell(ElixirLS.LanguageServer.MixShell)
    Mix.Hex.ensure_updated?()

    WireProtocol.stream_packets(&JsonRpc.receive_packet/1)
  end

  defp configure_logger do
    use Mix.Config

    Mix.Config.persist(
      logger: [
        handle_otp_reports: true,
        handle_sasl_reports: true,
        level: :warn,
        backends: [{ElixirLS.LanguageServer.LoggerBackend, :lsp_logger_backend}]
      ]
    )

    logger = Process.whereis(Logger)
    if logger, do: Logger.App.stop()
    Logger.App.start()
  end
end
