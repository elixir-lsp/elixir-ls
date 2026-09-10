defmodule ElixirLS.LanguageServer.MCP.TCPServer do
  @moduledoc """
  Fixed TCP server for MCP
  """

  use GenServer

  alias ElixirLS.LanguageServer.MCP.RequestHandler

  def start_link(opts) do
    port = Keyword.get(opts, :port, 3798)
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @impl true
  def init(port) do
    IO.puts("[MCP] Starting TCP Server, trying port #{port}")

    case find_available_port(port) do
      {:ok, actual_port, listen_socket} ->
        IO.puts("[MCP] Server listening on port #{actual_port}")
        send(self(), :accept)
        {:ok, %{listen: listen_socket, port: actual_port, clients: %{}}}

      {:error, reason} ->
        IO.puts(
          "[MCP] Failed to listen on 127.0.0.1 starting from port #{port}: #{inspect(reason)}"
        )

        # Do not take the language server down: binding one address can fail
        # where the wildcard bind could not, and only :eaddrinuse is retried.
        :ignore
    end
  end

  @impl true
  def handle_info(:accept, state) do
    IO.puts("[MCP] Starting accept process")

    # Accept in a separate process
    me = self()

    spawn(fn ->
      accept_connection(me, state.listen)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:accepted, socket}, state) do
    IO.puts("[MCP] Client socket accepted: #{inspect(socket)}")

    # Configure socket
    case :inet.setopts(socket, [{:active, true}]) do
      :ok -> IO.puts("[MCP] Socket set to active mode")
      {:error, reason} -> IO.puts("[MCP] Failed to set active: #{inspect(reason)}")
    end

    # Store client
    {:noreply, %{state | clients: Map.put(state.clients, socket, %{})}}
  end

  @impl true
  def handle_info({:tcp, socket, data} = msg, state) do
    IO.puts("[MCP] TCP message received!")
    IO.puts("[MCP] Full message: #{inspect(msg)}")
    IO.puts("[MCP] Data: #{inspect(data)}")

    # Process the request
    trimmed = String.trim(data)

    response =
      case JasonV.decode(trimmed) do
        {:ok, request} ->
          IO.puts("[MCP] Decoded request: #{inspect(request)}")
          RequestHandler.handle_request(request)

        {:error, _reason} ->
          %{
            "jsonrpc" => "2.0",
            "error" => %{
              "code" => -32700,
              "message" => "Parse error"
            },
            "id" => nil
          }
      end

    # Send response (only if not nil - notifications don't get responses)
    if response do
      case JasonV.encode(response) do
        {:ok, json} ->
          IO.puts("[MCP] Sending response: #{json}")
          :gen_tcp.send(socket, json <> "\n")

        {:error, _} ->
          :ok
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    IO.puts("[MCP] Client disconnected")
    {:noreply, %{state | clients: Map.delete(state.clients, socket)}}
  end

  @impl true
  def handle_info({:tcp_error, socket, reason}, state) do
    IO.puts("[MCP] TCP error: #{inspect(reason)}")
    :gen_tcp.close(socket)
    {:noreply, %{state | clients: Map.delete(state.clients, socket)}}
  end

  @impl true
  def handle_info(msg, state) do
    IO.puts("[MCP] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp find_available_port(start_port, max_attempts \\ 100) do
    find_available_port(start_port, start_port, max_attempts)
  end

  defp find_available_port(current_port, start_port, attempts_left) when attempts_left > 0 do
    case :gen_tcp.listen(current_port, [
           :binary,
           ip: {127, 0, 0, 1},
           packet: :line,
           active: false,
           reuseaddr: true
         ]) do
      {:ok, listen_socket} ->
        {:ok, current_port, listen_socket}

      {:error, :eaddrinuse} ->
        find_available_port(current_port + 1, start_port, attempts_left - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_available_port(_current_port, start_port, 0) do
    {:error, "No available ports found starting from #{start_port}"}
  end

  defp accept_connection(parent, listen_socket) do
    IO.puts("[MCP] Waiting for connection...")

    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        IO.puts("[MCP] Connection accepted!")
        # IMPORTANT: Set the controlling process to the GenServer
        :gen_tcp.controlling_process(socket, parent)
        send(parent, {:accepted, socket})

        # Continue accepting
        accept_connection(parent, listen_socket)

      {:error, reason} when reason in [:closed, :einval] ->
        # The server stopped and closed the listen socket. Without this clause
        # the loop retries forever, since it is not linked to the GenServer.
        IO.puts("[MCP] Listen socket closed, stopping accept loop")
        :ok

      {:error, reason} ->
        IO.puts("[MCP] Accept error: #{inspect(reason)}")
        Process.sleep(1000)
        accept_connection(parent, listen_socket)
    end
  end
end
