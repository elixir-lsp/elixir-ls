defmodule ElixirLS.Debugger.Output do
  @moduledoc """
  Implements the JSON-based request protocol for VS Code debug adapters.

  VS Code debug protocol specifies that a message is either a request, a response, or an event. 
  All messages must include a sequence number. This server keeps a counter to ensure that messages
  are sent with sequence numbers that are unique and sequential, and includes client functions for
  sending these messages.
  """
  use GenServer
  use ElixirLS.Debugger.Protocol

  ## Client API

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, 1, name: name)
  end

  def send_response(server \\ __MODULE__, request_packet, response_body) do
    GenServer.call(server, {:send_response, request_packet, response_body})
  end

  def send_event(server \\ __MODULE__, event, body) do
    GenServer.call(server, {:send_event, event, body})
  end

  ## Server callbacks

  def handle_call({:send_response, request_packet, body}, _from, seq) do
    ElixirLS.IOHandler.send(response(seq, request_packet["seq"], request_packet["command"], body))
    {:reply, :ok, seq + 1}
  end

  def handle_call({:send_event, event, body}, _from, seq) do
    ElixirLS.IOHandler.send(event(seq, event, body))
    {:reply, :ok, seq + 1}
  end

  def handle_call(message, from, s) do
    super(message, from, s)
  end
end