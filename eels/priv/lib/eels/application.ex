defmodule Eels.Application do
  @doc """
  Eels application startup. Note that we assume that we are started from the
  Elixir LS distribution root.
  """
  use Application

  def start(_type, _args) do
    IO.puts(:stderr, "Starting EELS application")
    start_distribution()
    start_language_server()
    start_supervisor()
  end

  defp start_supervisor do
    children = [
      {Eels.LSClient, get_language_server()},
      Eels.InputForwarder
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp start_distribution do
    System.cmd("epmd", ["-daemon"])
    {:ok, _mypid} = :net_kernel.start([my_name(), :shortnames])
    :erlang.set_cookie(:erlang.node(), cookie())
    IO.puts(:stderr, "System started on #{inspect :erlang.node()}")
  end

  defp start_language_server(tries \\ 3)
  defp start_language_server(0)do
    IO.puts(:stderr, "Could not start language server after 3 tries, exiting!")
    System.halt(:abort)
  end

  defp start_language_server(tries) do
    if get_language_server() == nil do
      System.cmd(File.cwd!() <> "/bin/language_server", ["daemon"])
      Process.sleep(2_000)
      if get_language_server() == nil do
        start_language_server(tries - 1)
      else
        IO.puts(:stderr, "Started and connected to language server")
      end
    else
      IO.puts(:stderr, "Connected to language server")
    end
  end

  def get_language_server do
    if :net_kernel.connect_node(ls_name()) do
      ls_name()
    else
      nil
    end
  end

  def my_name do
    String.to_atom("eels-#{System.pid()}")
  end

  def ls_name do
    String.to_atom("language_server@" <> local_short_name())
  end

  def local_short_name do
    :net_adm.localhost()
    |> List.to_string()
    |> String.split(".")
    |> Enum.at(0)
  end

  # TODO make it work in MIX_ENV == development
  def cookie do
    "releases/COOKIE"
    |> File.read!()
    |> String.to_atom()
  end
end
