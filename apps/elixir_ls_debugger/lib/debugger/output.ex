defmodule ElixirLS.Debugger.Output do
  @moduledoc """
  Implements the JSON-based request protocol for VS Code debug adapters.

  VS Code debug protocol specifies that a message is either a request, a response, or an event.
  All messages must include a sequence number. This server keeps a counter to ensure that messages
  are sent with sequence numbers that are unique and sequential, and includes client functions for
  sending these messages.
  """
  alias ElixirLS.Utils.WireProtocol
  use GenServer
  use ElixirLS.Debugger.Protocol

  ## Client API

  def start(name \\ __MODULE__) do
    GenServer.start(__MODULE__, :ok, name: name)
  end

  def send_response(server \\ __MODULE__, request_packet, response_body) do
    GenServer.call(server, {:send_response, request_packet, response_body})
  end

  def send_error_response(server \\ __MODULE__, request_packet, message, format, variables) do
    GenServer.call(server, {:send_error_response, request_packet, message, format, variables})
  end

  def send_event(server \\ __MODULE__, event, body) do
    GenServer.call(server, {:send_event, event, body})
  end

  def debugger_console(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, "output", %{"category" => "console", "output" => str})
  end

  def debugger_important(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, "output", %{"category" => "important", "output" => str})
  end

  def debuggee_out(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, "output", %{"category" => "stdout", "output" => str})
  end

  def debuggee_err(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, "output", %{"category" => "stderr", "output" => str})
  end

  ## Server callbacks

  @impl GenServer
  def init(:ok) do
    {:ok, 1}
  end

  @impl GenServer
  def handle_call({:send_response, request_packet, body}, _from, seq) do
    res = WireProtocol.send(response(seq, request_packet["seq"], request_packet["command"], body))
    {:reply, res, seq + 1}
  end

  def handle_call({:send_error_response, request_packet, message, format, variables}, _from, seq) do
    res =
      WireProtocol.send(
        error_response(
          seq,
          request_packet["seq"],
          request_packet["command"],
          message,
          format,
          variables
        )
      )

    {:reply, res, seq + 1}
  end

  def handle_call({:send_event, event, body}, _from, seq) do
    res = WireProtocol.send(event(seq, event, body))
    {:reply, res, seq + 1}
  end
end
