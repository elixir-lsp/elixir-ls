defmodule ElixirLS.DebugAdapter.Application do
  @moduledoc """
  Debug adapter for Elixir Mix tasks using Debug Adapter Protocol
  """

  use Application
  alias ElixirLS.DebugAdapter.Output
  alias ElixirLS.DebugAdapter.{Server, BreakpointCondition, ModuleInfoCache, CompilationListener}

  @impl Application
  def start(_type, _args) do
    # We don't start this as a worker because if the debug adapter crashes, we want
    # this process to remain alive to print errors
    {:ok, _pid} = Output.start(Output)

    if Version.match?(System.version(), ">= 1.14.0-dev") do
      Application.put_env(:elixir, :dbg_callback, {Server, :dbg, []})
    end

    children =
      if Mix.env() != :test do
        [
          BreakpointCondition,
          CompilationListener,
          {ModuleInfoCache, %{}},
          {Server, name: Server}
        ]
      else
        []
      end

    opts = [strategy: :one_for_one, name: ElixirLS.DebugAdapter.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def stop(_state) do
    :ok
  end
end
