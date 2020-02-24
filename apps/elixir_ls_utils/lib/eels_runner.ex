defmodule ElixirLS.Utils.EelsRunner do
  @moduledoc """
  Eels wrapper. This starts an inferior VM that (hopefully) runs the
  current project's code and forwards commands to it.
  """
  use GenServer
  require Logger

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # This might be a bottleneck. A simple optimization would be to stash
  # the node in ETS and leave the genserver just operate as an ETS owner
  # process.
  def exec(module, function, arguments) do
    GenServer.call(__MODULE__, {:exec, module, function, arguments})
  end

  def init([]) do
    {node, cookie} = generate_state()
    start_eels_vm(node, cookie)
    exec_ping(node)
    Logger.info("Eels runner successfully started")
    {:ok, node}
  end

  def handle_call(call = {:exec, module, function, arguments}, _from, node) do
    result = GenServer.call({:eels_server, node}, call)
    {:reply, result, node}
  end

  defp generate_state() do
    max = 2_000_000_000_000 # lots of birthdays need to happen...
    cookie = :"eels-cookie-#{:rand.uniform(max)}"
    node = :"eels-#{:rand.uniform(max)}"
    {node, cookie}
  end

  defp start_eels_vm(node, cookie) do
    :erlang.set_cookie(node, cookie)
    System.put_env("EELS_COOKIE", cookie)
    System.put_env("EELS_NODE", node)
    System.put_env("EELS_VERSION", Keyword.get(Application.spec(:eels), :vsn))
    script = Application.app_dir(:elixir_ls_utils <> "/priv/start_eels")
    # TODO Should we keep the port around?
    Port.open({:command, script <> " start"})
  end

  defp exec_ping(node) do
    # TODO clean up
    Process.sleep(2_000)
    result = GenServer.call({:eels_server, node}, {:exec, Kernel, :node, []})
    Logger.info("Result = #{inspect result}
  end

end
