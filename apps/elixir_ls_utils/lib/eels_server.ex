defmodule ElixirLS.Utils.EelsServer  do
  @moduledoc """
  Server for `Eels.LSClient`.

  TODO: Work as language server of debugging server. Design for that is still tbd.
  """
  use GenServer
  require Logger

  @ls_process_name :ExLSServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @ls_process_name)
  end

  @doc """
  Execute the indicated code on the remote node; return whatever it returns.
  """
  def execute(pid, {module, func, args}) do
    GenServer.call(pid, {:execute, {module, func, args}})
  end

  @doc """
  Print the indicated output on the remote node.
  """
  def send_output_data(pid, data) do
    GenServer.cast(pid, {:print, data})
  end

  def init(_args) do
    Logger.info("GenServer running on #{inspect self()}")
    {:ok, []}
  end

  # Received from Eels client instance to register it as a new project specific node
  def handle_cast({:register, pid}, state) do
    Logger.info("Received registration request from #{inspect pid}")
    # TODO The simplest way to hook into the existing code is by executing
    # intercept_output and then stream packets directly from the remote. It
    # also keeps more code "here" than "there". The alternative is to just
    # forward with the `:input` and `:print` casts.
    {:noreply, state}
  end

  # Received from Eels client instance to forward received LSP commands
  def handle_cast({:input, data, node}, state) do
    Logger.info("Received input #{inspect data} from #{inspect node}")
    {:noreply, state}
  end

end
