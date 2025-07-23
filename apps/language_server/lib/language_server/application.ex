defmodule ElixirLS.LanguageServer.Application do
  @moduledoc """
  Implementation of Language Server Protocol for Elixir
  """
  use Application

  alias ElixirLS.LanguageServer

  @impl Application
  def start(_type, _args) do
    children =
      [
        {LanguageServer.Server, LanguageServer.Server},
        {LanguageServer.JsonRpc, name: LanguageServer.JsonRpc},
        {LanguageServer.Providers.WorkspaceSymbols, []},
        {LanguageServer.Tracer, []},
        {LanguageServer.MixProjectCache, []},
        {LanguageServer.Parser, []},
        {LanguageServer.ExUnitTestTracer, []},
        {ElixirLS.LanguageServer.MCP.TCPServer, port: 3798}
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

      unless :persistent_term.get(:language_server_test_mode, false) do
        Process.sleep(2000)
        System.halt(1)
      else
        IO.warn("Application stopping")
      end
    end

    :ok
  end

  @spec restart() :: no_return()
  def restart() do
    Application.put_env(:language_server, :restart, true)
    System.halt(0)
  end
end
