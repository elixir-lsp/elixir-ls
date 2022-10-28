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
    Experimental.LanguageServer.persist_enabled_state()

    children =
      [
        maybe_experimental_supervisor(),
        {ElixirLS.LanguageServer.Server, ElixirLS.LanguageServer.Server},
        maybe_packet_router(),
        jsonrpc(),
        {ElixirLS.LanguageServer.Providers.WorkspaceSymbols, []},
        {ElixirLS.LanguageServer.Tracer, []},
        {ElixirLS.LanguageServer.ExUnitTestTracer, []}
      ]
      |> Enum.reject(&is_nil/1)

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

  defp maybe_experimental_supervisor do
    if Experimental.LanguageServer.enabled?() do
      Experimental.Supervisor
    end
  end

  defp maybe_packet_router do
    if Experimental.LanguageServer.enabled?() do
      {ElixirLS.LanguageServer.PacketRouter, [LanguageServer.Server, Experimental.Server]}
    end
  end

  defp jsonrpc do
    if Experimental.LanguageServer.enabled?() do
      {ElixirLS.LanguageServer.JsonRpc,
       name: ElixirLS.LanguageServer.JsonRpc, language_server: LanguageServer.PacketRouter}
    else
      {ElixirLS.LanguageServer.JsonRpc, name: ElixirLS.LanguageServer.JsonRpc}
    end
  end
end
