defmodule ElixirLS.Utils.OutputDevice do
  @moduledoc """
  Intercepts IO request messages and forwards them to the Output server to be sent as events to
  the IDE.

  In order to send console output to Visual Studio Code, the debug adapter needs to send events
  using the usual wire protocol. In order to intercept the debugged code's output, we replace the
  registered processes `:user` and `:standard_error` and the process's group leader with instances
  of this server. When it receives a message containing output, it sends an event via the `Output`
  server with the correct category ("stdout" or "stderr").
  """

  use GenServer

  ## Client API

  def start_link(device, output_fn, opts \\ []) do
    GenServer.start_link(__MODULE__, {device, output_fn}, opts)
  end

  ## Server callbacks

  def init({device, output_fn}) do
    {:ok, {device, output_fn}}
  end

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

  # Any other message (get_geometry, set_opts, etc.) goes directly to original device
  def handle_info(msg, {device, _} = s) do
    send(device, msg)
    {:noreply, s}
  end

  ## Helpers

  defp output(from, reply_as, characters, {_, output_fn}) do
    output_fn.(characters)
    send(from, {:io_reply, reply_as, :ok})
  end

end
