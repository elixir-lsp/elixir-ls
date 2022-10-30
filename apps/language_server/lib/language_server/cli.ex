defmodule ElixirLS.LanguageServer.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Build
  require Logger

  def main do
    WireProtocol.intercept_output(&JsonRpc.print/1, &JsonRpc.print_err/1)

    # :logger application is already started
    # replace console logger with LSP
    Application.put_env(:logger, :backends, [Logger.Backends.JsonRpc])

    Application.put_env(:logger, Logger.Backends.JsonRpc,
      level: :debug,
      format: "$message",
      metadata: []
    )

    {:ok, _} = Logger.add_backend(Logger.Backends.JsonRpc)
    :ok = Logger.remove_backend(:console, flush: true)

    Launch.start_mix()

    Build.set_compiler_options()

    start_language_server()

    Logger.info("Started ElixirLS v#{Launch.language_server_version()}")

    versions = Launch.get_versions()

    Logger.info(
      "ElixirLS built with elixir #{versions.compile_elixir_version} on OTP #{versions.compile_otp_version}"
    )

    Logger.info(
      "Running on elixir #{versions.current_elixir_version} on OTP #{versions.current_otp_version}"
    )

    check_otp_doc_chunks()

    Launch.limit_num_schedulers()

    Mix.shell(ElixirLS.LanguageServer.MixShell)
    # FIXME: Private API
    Mix.Hex.ensure_updated?()

    WireProtocol.stream_packets(&JsonRpc.receive_packet/1)
  end

  defp incomplete_installation_message(hash \\ "") do
    guide =
      "https://github.com/elixir-lsp/elixir-ls/blob/master/guides/incomplete-installation.md"

    "Unable to start ElixirLS due to an incomplete erlang installation. " <>
      "See #{guide}#{hash} for guidance."
  end

  defp start_language_server do
    case Application.ensure_all_started(:language_server, :temporary) do
      {:ok, _} ->
        :ok

      {:error, {:edoc, {'no such file or directory', 'edoc.app'}}} ->
        message = incomplete_installation_message("#edoc-missing")

        JsonRpc.show_message(:error, message)
        Process.sleep(5000)
        raise message

      {:error, {:dialyzer, {'no such file or directory', 'dialyzer.app'}}} ->
        message = incomplete_installation_message("#dialyzer-missing")

        JsonRpc.show_message(:error, message)
        Process.sleep(5000)
        raise message

      {:error, _} ->
        message = incomplete_installation_message()

        JsonRpc.show_message(:error, message)
        Process.sleep(5000)
        raise message
    end
  end

  def check_otp_doc_chunks() do
    if match?({:error, _}, Code.fetch_docs(:erlang)) do
      JsonRpc.show_message(:warning, "OTP compiled without EEP48 documentation chunks")
      Logger.warn("OTP compiled without EEP48 documentation chunks. Language features for erlang modules will run in limited mode. Please reinstall or rebuild OTP with approperiate flags.")
    end
  end
end
