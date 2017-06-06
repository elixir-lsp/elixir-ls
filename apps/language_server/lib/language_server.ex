defmodule ElixirLS.LanguageServer do
  @moduledoc """
  Implementation of Language Server Protocol for Elixir
  """
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(ElixirLS.LanguageServer.Builder, [ElixirLS.LanguageServer.Builder]),
      worker(ElixirLS.LanguageServer.Server, [ElixirLS.LanguageServer.Server]),
      worker(ElixirLS.IOHandler, 
             [ElixirLS.LanguageServer.Server, [name: ElixirLS.LanguageServer.IOHandler]]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirLanguageServer.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    :init.stop
  end
end
