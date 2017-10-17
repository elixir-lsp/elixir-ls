defmodule ElixirLS.LanguageServer do
  @moduledoc """
  Implementation of Language Server Protocol for Elixir
  """
  require Logger
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(ElixirLS.LanguageServer.Server, [ElixirLS.LanguageServer.Server]),
      worker(ElixirLS.LanguageServer.JsonRpc, [[name: ElixirLS.LanguageServer.JsonRpc]]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirLS.LanguageServer.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    # If IO is being intercepted (meaning we're running in production), allow time to flush errors
    # then kill the VM
    if ElixirLS.Utils.WireProtocol.io_intercepted?() do
      IO.puts("Stopping ElixirLS due to errors.")
      :timer.sleep(100)
      :init.stop(1)
    end

    :ok
  end
end
