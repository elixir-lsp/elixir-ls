defmodule ElixirLS.LanguageServer.CLI do
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.LanguageServer.JsonRpc

  def main do
    WireProtocol.intercept_output(&JsonRpc.print/1, &JsonRpc.print_err/1)
    Launch.start_mix()

    start_language_server()

    IO.puts("Started ElixirLS v#{Launch.language_server_version()}")
    Launch.print_versions()
    Launch.limit_num_schedulers()

    Mix.shell(ElixirLS.LanguageServer.MixShell)
    # FIXME: Private API
    Mix.Hex.ensure_updated?()

    WireProtocol.stream_packets(&JsonRpc.receive_packet/1)
  end

  defp start_language_server do
    guide =
      "https://github.com/elixir-lsp/elixir-ls/blob/master/guides/incomplete-installation.md"

    case Application.ensure_all_started(:language_server, :temporary) do
      {:ok, _} ->
        :ok

      {:error, {:edoc, {'no such file or directory', 'edoc.app'}}} ->
        raise "Unable to start ElixirLS due to an incomplete erlang installation. " <>
                "See #{guide}#edoc-missing for guidance."

      {:error, {:dialyzer, {'no such file or directory', 'dialyzer.app'}}} ->
        raise "Unable to start ElixirLS due to an incomplete erlang installation. " <>
                "See #{guide}#dialyzer-missing for guidance."

      {:error, _} ->
        raise "Unable to start ElixirLS due to an incomplete erlang installation. " <>
                "See #{guide} for guidance."
    end
  end
end
