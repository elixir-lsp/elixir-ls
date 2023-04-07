defmodule ElixirLS.Debugger do
  @moduledoc """
  Debugger adapter for Elixir Mix tasks using VS Code Debug Protocol
  """

  use Application
  alias ElixirLS.Debugger.Output

  @impl Application
  def start(_type, _args) do
    # We don't start this as a worker because if the debugger crashes, we want
    # this process to remain alive to print errors
    {:ok, _pid} = Output.start(Output)

    children = [
      {ElixirLS.Debugger.Server, name: ElixirLS.Debugger.Server}
    ]

    opts = [strategy: :one_for_one, name: ElixirLS.Debugger.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def stop(_state) do
    :ok
  end
end
