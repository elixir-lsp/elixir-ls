defmodule ElixirLS.Debugger do
  @moduledoc """
  Debugger adapter for Elixir Mix tasks using VS Code Debug Protocol
  """

  use Application

  @impl Application
  def start(_type, _args) do
    # We don't start this as a worker because if the debugger crashes, we want
    # this process to remain alive to print errors
    {:ok, _pid} = ElixirLS.Debugger.Output.start(ElixirLS.Debugger.Output)

    children = [
      {ElixirLS.Debugger.Server, name: ElixirLS.Debugger.Server}
    ]

    opts = [strategy: :one_for_one, name: ElixirLS.Debugger.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def stop(_state) do
    if ElixirLS.Utils.WireProtocol.io_intercepted?() do
      IO.puts(:standard_error, "ElixirLS debugger has crashed")

      :init.stop(1)
    end

    :ok
  end
end
