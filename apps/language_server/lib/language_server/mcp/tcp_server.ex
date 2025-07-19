defmodule ElixirLS.LanguageServer.MCP.TCPServer do
  @moduledoc """
  Fixed TCP server for MCP
  """

  use GenServer
  require Logger

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
    IO.puts("[MCP] Starting TCP Server on port #{port}")

    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        IO.puts("[MCP] Server listening on port #{port}")
        send(self(), :accept)
        {:ok, %{listen: listen_socket, clients: %{}}}

      {:error, reason} ->
        IO.puts("[MCP] Failed to listen on port #{port}: #{inspect(reason)}")
        {:stop, reason}
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

      {:error, reason} ->
        IO.puts("[MCP] Accept error: #{inspect(reason)}")
        Process.sleep(1000)
        accept_connection(parent, listen_socket)
    end
  end
end
