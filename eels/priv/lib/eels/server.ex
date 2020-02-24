defmodule Eels.Server do
  @moduledoc """
  Language server server. This receives commands from the language server and executes
  them. There is a big trust relationship between this VM and the LS VM so we allow
  the server to do a lot; our main function is to separate namespaces and BEAM versions,
  not to act as a trust boundary.
  """
  use GenServer
  require Logger

  # Known name for the language server/debugger to find us under.
  @name :eels_server

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init([]) do
    Logger.info("Eels server running on #{inspect node()}/#{inspect self()}")
    {:ok, []}
  end

  # Call from server to execute code in our node. Yes, anything goes.
  def handle_call({:exec, module, func, args}, _from, state) do
    result = Kernel.apply(module, func, args)
    Logger.info("execute #{module}/#{func}/#{inspect args} -> #{inspect result}")
    {:reply, result, state}
  end
end
