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

  def handle_call(call = {:exec, _module, _function, _arguments}, _from, node) do
    result = GenServer.call({:eels_server, node}, call)
    {:reply, result, node}
  end

  defp generate_state() do
    max = 2_000_000_000_000 # lots of birthdays need to happen...
    cookie = :"eels-cookie-#{:rand.uniform(max)}"
    host = node |> Atom.to_string() |> String.split("@") |> List.last()
    node = :"eels-#{:rand.uniform(max)}@#{host}"
    {node, cookie}
  end

  defp start_eels_vm(node, cookie) do
    System.put_env("EELS_COOKIE", Atom.to_string(Node.get_cookie()))
    System.put_env("EELS_NODE", Atom.to_string(node))
    System.put_env("EELS_VERSION", List.to_string(Keyword.get(Application.spec(:eels), :vsn)))
    script = Application.app_dir(:elixir_ls_utils) <> "/priv/start_eels"
    # TODO Should we keep the port around?
    Port.open({:spawn, script <> " start"}, [])
    Process.sleep(2_000) # TODO clean up
    Logger.info("Connected: #{inspect Node.connect(node)}")
  end

  defp exec_ping(node) do
    result = GenServer.call({:eels_server, node}, {:exec, Kernel, :node, []})
    Logger.info("Result = #{inspect result}")
  end

end
