#!/usr/bin/env elixir

# TCP to STDIO bridge for MCP
# This allows Claude to connect to our TCP-based MCP server

defmodule TCPToSTDIOBridge do
  require Logger

  def start(host \\ "localhost", port \\ 3798) do
    # Configure Logger to write to a file instead of stderr
    log_file = Path.join(System.tmp_dir!(), "mcp_bridge.log")
    Logger.configure(backends: [{LoggerFileBackend, :file_log}])

    Logger.configure_backend({LoggerFileBackend, :file_log},
      path: log_file,
      level: :debug
    )

    # Set stdio to binary mode with latin1 encoding (same as ElixirLS)
    :io.setopts(:standard_io, [:binary, encoding: :latin1])

    Logger.debug("Starting bridge to #{host}:#{port}")

    case :gen_tcp.connect(to_charlist(host), port, [
           :binary,
           active: false,
           packet: :line,
           buffer: 65536
         ]) do
      {:ok, socket} ->
        Logger.debug("Connected to TCP server")
        # Initialize with active: false for proper control
        bridge_loop(socket, "")

      {:error, reason} ->
        Logger.error("Failed to connect: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp bridge_loop(socket, buffer) do
    # Set up stdin reader in a separate process
    parent = self()

    if buffer == "" do
      spawn_link(fn -> stdin_reader(parent) end)
    end

    # Set socket to active once for receiving one message
    :inet.setopts(socket, [{:active, :once}])

    receive do
      # Handle data from stdin
      {:stdin, data} ->
        Logger.debug("STDIN -> TCP: #{inspect(data)}")
        :gen_tcp.send(socket, data)
        bridge_loop(socket, buffer)

      # Handle data from TCP
      {:tcp, ^socket, data} ->
        Logger.debug("TCP -> STDOUT: #{inspect(data)}")
        IO.write(:standard_io, data)
        bridge_loop(socket, buffer)

      {:tcp_closed, ^socket} ->
        Logger.info("TCP connection closed")
        System.halt(0)

      {:tcp_error, ^socket, reason} ->
        Logger.error("TCP error: #{inspect(reason)}")
        System.halt(1)

      {:stdin_eof} ->
        Logger.info("STDIN EOF")
        :gen_tcp.close(socket)
        System.halt(0)
    end
  end

  defp stdin_reader(parent) do
    case IO.read(:standard_io, :line) do
      :eof ->
        send(parent, {:stdin_eof})

      {:error, reason} ->
        Logger.error("STDIN error: #{inspect(reason)}")
        send(parent, {:stdin_eof})

      data when is_binary(data) ->
        send(parent, {:stdin, data})
        stdin_reader(parent)
    end
  end
end

# Simple logger backend that writes to a file
defmodule LoggerFileBackend do
  @behaviour :gen_event

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  def handle_call({:configure, opts}, %{name: name}) do
    {:ok, :ok, configure(name, opts)}
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end

    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp configure(name, opts) when is_binary(name) do
    state = %{
      name: name,
      path: nil,
      file: nil,
      level: :debug
    }

    configure(state, opts)
  end

  defp configure(state, opts) do
    path = Keyword.get(opts, :path)
    level = Keyword.get(opts, :level, :debug)

    state = %{state | path: path, level: level}

    if state.file do
      File.close(state.file)
    end

    case path do
      nil ->
        state

      _ ->
        case File.open(path, [:append, :utf8]) do
          {:ok, file} -> %{state | file: file}
          _ -> state
        end
    end
  end

  defp log_event(level, msg, {date, time}, _md, %{file: file}) when not is_nil(file) do
    timestamp = Logger.Formatter.format_date(date) <> " " <> Logger.Formatter.format_time(time)
    IO.write(file, "[#{timestamp}] [#{level}] #{msg}\n")
  end

  defp log_event(_, _, _, _, _), do: :ok
end

# Parse command line arguments
args = System.argv()

{host, port} =
  case args do
    [host, port] -> {host, String.to_integer(port)}
    [port] -> {"localhost", String.to_integer(port)}
    _ -> {"localhost", 3798}
  end

# Start the bridge
TCPToSTDIOBridge.start(host, port)
