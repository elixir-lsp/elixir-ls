defmodule ElixirLS.LanguageServer.MCP.Supervisor do
  use Supervisor

  def start_link(parent \\ self(), name \\ nil, port) do
    Supervisor.start_link(__MODULE__, {parent, port}, name: name || __MODULE__)
  end

  @impl Supervisor
  def init({_parent, port}) do
    Supervisor.init(
      [
        {ElixirLS.LanguageServer.MCP.TCPServer, port: port}
      ],
      strategy: :one_for_one
    )
  end
end
