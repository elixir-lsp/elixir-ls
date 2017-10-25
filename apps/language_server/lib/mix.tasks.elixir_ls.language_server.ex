defmodule Mix.Tasks.ElixirLs.LanguageServer do
  alias ElixirLS.Utils.WireProtocol
  alias ElixirLS.LanguageServer.JsonRpc

  def run(_args) do
    WireProtocol.intercept_output(&JsonRpc.print/1, &JsonRpc.print_err/1)
    configure_logger()
    Application.ensure_all_started(:language_server, :permanent)
    Mix.shell(ElixirLS.LanguageServer.MixShell)
    WireProtocol.stream_packets(&JsonRpc.receive_packet/1)
  end

  defp configure_logger do
    use Mix.Config

    Mix.Config.persist(logger: [
      handle_otp_reports: true,
      handle_sasl_reports: true,
      level: :warn,
      backends: [{ElixirLS.LanguageServer.LoggerBackend, :lsp_logger_backend}]
    ])

    logger = Process.whereis(Logger)
    if logger, do: Logger.App.stop()
    Logger.App.start()
  end
end
