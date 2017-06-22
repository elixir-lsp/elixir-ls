defmodule ElixirLS.Debugger do
  @moduledoc """
  Debugger adapter for Elixir Mix tasks using VS Code Debug Protocol
  """

  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(ElixirLS.Debugger.Output, [ElixirLS.Debugger.Output]),
      worker(ElixirLS.Debugger.OutputDevice,
             [:user, "stdout", [change_all_gls?: change_all_gls?()]],
             [id: ElixirLS.Debugger.OutputDevice.Stdout]),
      worker(ElixirLS.Debugger.OutputDevice, [:standard_error, "stderr"],
             [id: ElixirLS.Debugger.OutputDevice.Stderr]),
      worker(ElixirLS.Debugger.Server, [[name: ElixirLS.Debugger.Server]]),
      worker(ElixirLS.IOHandler, [ElixirLS.Debugger.Server, [name: ElixirLS.Debugger.IOHandler]]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirLS.Debugger.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    :init.stop
  end

  defp change_all_gls? do
    !(Enum.any?(Application.started_applications, &match?({:mix, _, _}, &1)) and Mix.env == :test)
  end
end
