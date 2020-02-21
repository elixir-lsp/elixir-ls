defmodule Eels.LSClient do
  @moduledoc """
  Language server client. This receives commands from the language server and executes
  them. There is a big trust relationship between this VM and the LS VM so we allow
  the server to do a lot; our main function is to separate namespaces and BEAM versions,
  not to act as a trust boundary.
  """
  use GenServer

  @ls_process_name :ExLSServer

  def start_link(server_node) do
    GenServer.start_link(__MODULE__, server_node, name: __MODULE__)
  end

  def send_input_data(data) do
    GenServer.cast(__MODULE__, {:input, data})
  end

  def init(server_node) do
    GenServer.cast({@ls_process_name, server_node}, {:register, self()})
    IO.puts(:stderr, "LS Client registered with #{server_node}")
    {:ok, server_node}
  end

  # Call from server to execute code in our node. Yes, anything goes.
  def handle_call({:execute, {module, func, args}}, _from, server_node) do
    result = Kernel.apply(module, func, args)
    {:reply, result, server_node}
  end

  # Call from server to print data to stdout (LSP replies)
  def handle_cast({:print, data}, server_node) do
    IO.puts(data)
    {:noreply, server_node}
  end

  # Call from forwarder to send read data to server (LSP requests)
  def handle_cast({:input, data}, server_node) do
    IO.inspect GenServer.cast({@ls_process_name, server_node}, {:input, data, self()})
    {:noreply, server_node}
  end
end
