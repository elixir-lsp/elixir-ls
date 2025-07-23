#!/usr/bin/env elixir
#
# MCP TCP-to-STDIO bridge
# This bridges between LLM like claude (using stdio) and ElixirLS MCP server (using TCP)

defmodule TcpToStdioBridge do
  def start(host \\ "localhost", port \\ 3798) do
    # Set stdio to binary mode with latin1 encoding
    :io.setopts(:standard_io, [:binary, encoding: :latin1])

    case :gen_tcp.connect(to_charlist(host), port, [
           :binary,
           active: false,
           packet: :line,
           buffer: 65536
         ]) do
      {:ok, socket} ->
        # Run the bridge
        bridge_loop(socket)

      {:error, _reason} ->
        # Can't write to stderr as it might confuse Claude
        System.halt(1)
    end
  end

  defp bridge_loop(socket) do
    # Spawn a task to handle stdin -> tcp
    parent = self()
    stdin_pid = spawn_link(fn -> stdin_reader(parent) end)

    # Handle tcp -> stdout in main process
    tcp_loop(socket, stdin_pid)
  end

  defp tcp_loop(socket, stdin_pid) do
    # Set socket to active once
    :inet.setopts(socket, [{:active, :once}])

    receive do
      # Data from stdin to forward to TCP
      {:stdin_data, data} ->
        :gen_tcp.send(socket, data)
        tcp_loop(socket, stdin_pid)

      # Data from TCP to forward to stdout
      {:tcp, ^socket, data} ->
        IO.write(:standard_io, data)
        tcp_loop(socket, stdin_pid)

      # TCP connection closed
      {:tcp_closed, ^socket} ->
        System.halt(0)

      # TCP error
      {:tcp_error, ^socket, _reason} ->
        System.halt(1)

      # Stdin closed
      :stdin_eof ->
        :gen_tcp.close(socket)
        System.halt(0)
    end
  end

  defp stdin_reader(parent) do
    case IO.read(:standard_io, :line) do
      :eof ->
        send(parent, :stdin_eof)

      {:error, _reason} ->
        send(parent, :stdin_eof)

      data when is_binary(data) ->
        send(parent, {:stdin_data, data})
        stdin_reader(parent)
    end
  end
end

# Start the bridge
TcpToStdioBridge.start()
