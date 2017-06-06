defmodule ElixirLS.Debugger.OutputDevice do
  @moduledoc """
  Intercepts IO request messages and forwards them to the Output server to be sent as events to 
  the IDE.

  In order to send console output to Visual Studio Code, the debug adapter needs to send events 
  using the usual wire protocol. In order to intercept the debugged code's output, we replace the 
  registered processes `:user` and `:standard_error` and the process's group leader with instances 
  of this server. When it receives a message containing output, it sends an event via the `Output` 
  server with the correct category ("stdout" or "stderr").
  """
  alias ElixirLS.Debugger.Output

  defstruct [:device_pid, :category]

  use GenServer

  ## Client API

  def start_link(device, category, opts \\ []) do
    device_pid = Process.whereis(device) || Process.group_leader

    initial = %__MODULE__{device_pid: device_pid, category: category}
    case GenServer.start_link(__MODULE__, initial, opts) do
      {:ok, pid} ->
        Process.unregister(device)
        Process.register(pid, device)

        if opts[:change_all_gls?] do
          for process <- :erlang.processes, process != pid and process != Process.whereis(Output) do
            Process.group_leader(process, pid)
          end
        end

        {:ok, pid}
      err ->
        err
    end
  end

  ## Server callbacks

  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, characters}}, s) do
    output(from, reply_as, characters, s)
    {:noreply, s}
  end

  def handle_info({:io_request, from, reply_as, {:put_chars, characters}}, s) do
    output(from, reply_as, characters, s)
    {:noreply, s}
  end

  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, module, func, args}}, 
                         s) do

    output(from, reply_as, apply(module, func, args), s)
    {:noreply, s}
  end

  def handle_info({:io_request, from, reply_as, {:put_chars, module, func, args}}, s) do
    output(from, reply_as, apply(module, func, args), s)
    {:noreply, s}
  end

  def handle_info({:io_request, from, reply_as, {:requests, reqs}}, s) do
    for req <- reqs do
      handle_info({:io_request, from, reply_as, req}, s)
    end
    {:noreply, s}
  end

  # Any other io_request (get_geometry, set_opts, etc.) goes directly to original device
  def handle_info({:io_request, from, reply_as, req}, s) do
    send(s.device_pid, {:io_request, from, reply_as, req})
    {:noreply, s}
  end

  def handle_info(msg, s) do
    super(msg, s)
  end

  ## Helpers

  defp output(from, reply_as, characters, s) do
    body = %{"category" => s.category, "output" => to_string(characters)}
    Output.send_event("output", body)
    send(from, {:io_reply, reply_as, :ok})
  end

end