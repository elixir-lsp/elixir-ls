defmodule Eels.Application do
  @doc """
  Eels application startup. Note that we assume that we are started from the
  Elixir LS distribution root.
  """
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Starting EELS application")
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
    {:ok, _mypid} = :net_kernel.start([my_node(), :shortnames])
    :erlang.set_cookie(node(), cookie())
    Logger.info("System started on #{inspect node()} with cookie #{cookie()}")
  end

  def my_node do
    "EELS_NODE"
    |> getenv("eels-default-node")
    |> String.to_atom()
  end

  def cookie do
    "EELS_COOKIE"
    |> getenv("eels-default-cookie")
    |> String.to_atom()
  end

  # Added to be compatible with then System.get_env/2 did not exist
  def getenv(name, default) do
    System.get_env(name) || default
  end
end
