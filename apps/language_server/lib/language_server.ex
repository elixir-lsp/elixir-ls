defmodule ElixirLS.LanguageServer do
  @moduledoc """
  Implementation of Language Server Protocol for Elixir
  """
  use Application

  alias ElixirLS.LanguageServer
  alias ElixirLS.LanguageServer.Experimental

  # @maybe_experimental_server [Experimental.Server]
  @maybe_experimental_server []

  @impl Application
  def start(_type, _args) do
    children = [
      Experimental.SourceFile.Store,
      {ElixirLS.LanguageServer.Server, ElixirLS.LanguageServer.Server},
      Experimental.Server,
      {ElixirLS.LanguageServer.PacketRouter,
       [LanguageServer.Server] ++ @maybe_experimental_server},
      {ElixirLS.LanguageServer.JsonRpc,
       name: ElixirLS.LanguageServer.JsonRpc, language_server: LanguageServer.PacketRouter},
      {ElixirLS.LanguageServer.Providers.WorkspaceSymbols, []},
      {ElixirLS.LanguageServer.Tracer, []},
      {ElixirLS.LanguageServer.ExUnitTestTracer, []}
    ]

    opts = [strategy: :one_for_one, name: LanguageServer.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def stop(_state) do
    if ElixirLS.Utils.WireProtocol.io_intercepted?() do
      LanguageServer.JsonRpc.show_message(
        :error,
        "ElixirLS has crashed. See Output panel."
      )

      :init.stop(1)
    end

    :ok
  end
end
