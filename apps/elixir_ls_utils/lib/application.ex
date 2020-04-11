defmodule ElixirLS.Utils.Application do
  use Application

  def start(_type, _args) do
    children = [
      ElixirLS.Utils.EelsRunner
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
