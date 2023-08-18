defmodule ElixirLS.LanguageServer do
  @moduledoc """
  Implementation of Language Server Protocol for Elixir
  """
  use Application

  alias ElixirLS.LanguageServer

  @impl Application
  def start(_type, _args) do
    children =
      [
        {ElixirLS.LanguageServer.Server, ElixirLS.LanguageServer.Server},
        {ElixirLS.LanguageServer.JsonRpc, name: ElixirLS.LanguageServer.JsonRpc},
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
    if not Application.get_env(:language_server, :restart, false) and
         ElixirLS.Utils.WireProtocol.io_intercepted?() do
      LanguageServer.JsonRpc.show_message(
        :error,
        "ElixirLS has crashed. See Output panel."
      )

      System.halt(1)
    end

    :ok
  end

  def restart() do
    Application.put_env(:language_server, :restart, true)
    System.stop(0)
  end
end
