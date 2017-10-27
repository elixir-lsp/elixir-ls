defmodule ElixirLS.Debugger do
  @moduledoc """
  Debugger adapter for Elixir Mix tasks using VS Code Debug Protocol
  """

  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # We don't start this as a worker because if the debugger crashes, we want
    # this process to remain alive to print errors
    ElixirLS.Debugger.Output.start(ElixirLS.Debugger.Output)

    children = [
      # Define workers and child supervisors to be supervised
      worker(ElixirLS.Debugger.Server, [[name: ElixirLS.Debugger.Server]]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirLS.Debugger.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    # If IO is being intercepted (meaning we're running in production), allow time to flush errors
    # then kill the VM
    if ElixirLS.Utils.WireProtocol.io_intercepted?() do
      IO.puts("Stopping ElixirLS debugger due to errors.")
      :timer.sleep(100)
      :init.stop(1)
    end

    :ok
  end
end
