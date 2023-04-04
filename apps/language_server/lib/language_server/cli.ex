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

    Application.put_env(:elixir_sense, :logging_enabled, Mix.env() != :prod)
    Build.set_compiler_options()

    start_language_server()

    Logger.info("Started ElixirLS v#{Launch.language_server_version()}")

    Logger.info("Running in #{File.cwd!()}")

    versions = Launch.get_versions()

    Logger.info(
      "ElixirLS built with elixir #{versions.compile_elixir_version} on OTP #{versions.compile_otp_version}"
    )

    Logger.info(
      "Running on elixir #{versions.current_elixir_version} on OTP #{versions.current_otp_version}"
    )

    check_otp_doc_chunks()
    check_elixir_sources()
    check_otp_sources()

    Launch.limit_num_schedulers()

    Mix.shell(ElixirLS.LanguageServer.MixShell)
    # FIXME: Private API
    true = Mix.Hex.ensure_installed?(false)
    true = Mix.Hex.ensure_updated?()

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

      Logger.warn(
        "OTP compiled without EEP48 documentation chunks. Language features for erlang modules will run in limited mode. Please reinstall or rebuild OTP with approperiate flags."
      )
    end
  end

  def check_elixir_sources() do
    enum_ex_path = Enum.module_info()[:compile][:source]

    unless File.exists?(enum_ex_path, [:raw]) do
      dir = Path.join(enum_ex_path, "../../../..") |> Path.expand()

      Logger.notice(
        "Elixir sources not found (checking in #{dir}). Code navigation to Elixir modules disabled."
      )
    end
  end

  def check_otp_sources() do
    {_module, _binary, beam_filename} = :code.get_object_code(:erlang)

    erlang_erl_path =
      beam_filename
      |> to_string
      |> String.replace(Regex.recompile!(~r/(.+)\/ebin\/([^\s]+)\.beam$/), "\\1/src/\\2.erl")

    unless File.exists?(erlang_erl_path, [:raw]) do
      dir = Path.join(erlang_erl_path, "../../../..") |> Path.expand()

      Logger.notice(
        "OTP sources not found (checking in #{dir}). Code navigation to OTP modules disabled."
      )
    end
  end
end
