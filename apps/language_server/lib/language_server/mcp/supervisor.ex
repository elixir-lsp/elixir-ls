defmodule ElixirLS.LanguageServer.MCP.Supervisor do
  use Supervisor

  def start_link(parent \\ self(), name \\ nil, opts) do
    Supervisor.start_link(__MODULE__, {parent, opts}, name: name || __MODULE__)
  end

  @impl Supervisor
  def init({_parent, opts}) do
    Supervisor.init(
      [
        {ElixirLS.LanguageServer.MCP.TCPServer, opts}
      ],
      strategy: :one_for_one
    )
  end
end
