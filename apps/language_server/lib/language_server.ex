defmodule ElixirLS.LanguageServer do
  @moduledoc """
  Implementation of Language Server Protocol for Elixir
  """
  require Logger
  use Application

  @impl Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(ElixirLS.LanguageServer.Server, [ElixirLS.LanguageServer.Server]),
      worker(ElixirLS.LanguageServer.JsonRpc, [[name: ElixirLS.LanguageServer.JsonRpc]])
    ]

    opts = [strategy: :one_for_one, name: ElixirLS.LanguageServer.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def stop(_state) do
    if ElixirLS.Utils.WireProtocol.io_intercepted?() do
      ElixirLS.LanguageServer.JsonRpc.show_message(
        :error,
        "ElixirLS has crashed. See Output panel."
      )

      :init.stop(1)
    end

    :ok
  end
end
