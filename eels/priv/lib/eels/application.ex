defmodule Eels.Application do
  @doc """
  Eels application startup. Note that we assume that we are started from the
  Elixir LS distribution root.
  """
  use Application

  def start(_type, _args) do
    IO.puts(:stderr, "Starting EELS application")
    start_distribution()
    start_supervisor()
  end

  defp start_supervisor do
    children = [
      Eels.Server,
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp start_distribution do
    System.cmd("epmd", ["-daemon"])
    {:ok, _mypid} = :net_kernel.start([my_node(), :shortnames])
    :erlang.set_cookie(:erlang.node(), cookie())
    IO.puts(:stderr, "System started on #{inspect :erlang.node()}")
  end

  def my_node do
    "EELS_NODE"
    |> System.get_env("eels-#{System.pid()}")
    |> String.to_atom()
  end

  # TODO make it work in MIX_ENV == development
  def cookie do
    "EELS_COOKIE"
    |> System.get_env("eels-default-cookie")
    |> String.to_atom()
  end
end
