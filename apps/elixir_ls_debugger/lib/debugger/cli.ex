defmodule ElixirLS.Debugger.CLI do
  alias ElixirLS.Utils
  alias ElixirLS.Utils.{WireProtocol, Launch}
  alias ElixirLS.Debugger.{Output, Server}

  def main do
    Application.load(:erts)
    Application.put_env(:elixir, :ansi_enabled, false)
    WireProtocol.intercept_output(&Output.debuggee_out/1, &Output.debuggee_err/1)
    Launch.start_mix()

    if Version.match?(System.version(), ">= 1.15.0") do
      # make sue that debugger modules are in code path
      # without starting the app
      Mix.ensure_application!(:debugger)
    end

    {:ok, _} = Application.ensure_all_started(:elixir_ls_debugger, :permanent)

    Output.debugger_console("Started ElixirLS Debugger v#{Launch.debugger_version()}")
    versions = Launch.get_versions()

    Output.debugger_console(
      "ElixirLS Debugger built with elixir #{versions.compile_elixir_version} on OTP #{versions.compile_otp_version}"
    )

    Output.debugger_console(
      "Running on elixir #{versions.current_elixir_version} on OTP #{versions.current_otp_version}"
    )

    Output.debugger_console(
      "Protocols are #{unless(Protocol.consolidated?(Enumerable), do: "not ", else: "")}consolidated"
    )

    Launch.limit_num_schedulers()
    warn_if_unsupported_version()

    Launch.unload_not_needed_apps([
      :nimble_parsec,
      :mix_task_archive_deps,
      :language_server,
      :dialyxir_vendored,
      :path_glob_vendored,
      :erlex_vendored,
      :erl2ex_vendored
    ])

    WireProtocol.stream_packets(&Server.receive_packet/1)
  end

  defp warn_if_unsupported_version do
    with {:error, message} <- Utils.MinimumVersion.check_elixir_version() do
      Output.debugger_important("WARNING: " <> message)
    end

    with {:error, message} <- Utils.MinimumVersion.check_otp_version() do
      Output.debugger_important("WARNING: " <> message)
    end
  end
end
