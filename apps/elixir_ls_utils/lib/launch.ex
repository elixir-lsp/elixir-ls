defmodule ElixirLS.Utils.Launch do
  @compiled_elixir_version System.version()
  @compiled_otp_version System.otp_release()

  def start_mix do
    # FIXME: Private API
    Mix.start()
    # FIXME: Private API
    Mix.Local.append_archives()
    # FIXME: Private API
    Mix.Local.append_paths()
    load_dot_config()
    :ok
  end

  def print_versions do
    IO.inspect(System.build_info()[:build], label: "Elixir version")
    IO.inspect(System.otp_release(), label: "Erlang version")

    IO.puts(
      "ElixirLS compiled with Elixir #{@compiled_elixir_version}" <>
        " and erlang #{@compiled_otp_version}"
    )
  end

  def language_server_version do
    {:ok, vsn} = :application.get_key(:language_server, :vsn)
    vsn
  end

  def debugger_version do
    {:ok, vsn} = :application.get_key(:debugger, :vsn)
    vsn
  end

  defp load_dot_config do
    # FIXME: Private API
    path = Path.join(Mix.Utils.mix_home(), "config.exs")

    if File.regular?(path) do
      Mix.Task.run("loadconfig", [path])
    end
  end
end
