defmodule ElixirLS.Utils.WireProtocol do
  @moduledoc """
  Reads and writes packets using the Language Server Protocol's wire protocol
  """
  alias ElixirLS.Utils.{PacketStream, OutputDevice}

  @separator "\r\n\r\n"

  def send(packet) do
    pid = io_dest()
    body = JasonV.encode_to_iodata!(packet)

    IO.binwrite(pid, [
      "Content-Length: ",
      IO.iodata_length(body) |> Integer.to_string(),
      @separator,
      body
    ])
  end

  defp io_dest do
    Process.whereis(:raw_user) || Process.group_leader()
  end

  def io_intercepted? do
    !!Process.whereis(:raw_standard_error)
  end

  def intercept_output(print_fn, print_err_fn) do
    raw_user = Process.whereis(:user)
    raw_standard_error = Process.whereis(:standard_error)

    :ok = :io.setopts(raw_user, binary: true, encoding: :latin1)

    {:ok, intercepted_user} = OutputDevice.start_link(raw_user, print_fn)
    {:ok, intercepted_standard_error} = OutputDevice.start_link(raw_user, print_err_fn)

    Process.unregister(:user)
    Process.register(raw_user, :raw_user)
    Process.register(intercepted_user, :user)

    Process.unregister(:standard_error)
    Process.register(raw_standard_error, :raw_standard_error)
    Process.register(intercepted_standard_error, :standard_error)

    for process <- :erlang.processes(), process not in [raw_user, raw_standard_error, intercepted_user, intercepted_standard_error] do
      Process.group_leader(process, intercepted_user)
    end
  end

  def undo_intercept_output() do
    intercepted_user = Process.whereis(:user)
    intercepted_standard_error = Process.whereis(:standard_error)

    Process.unregister(:user)
    raw_user = try do
      raw_user = Process.whereis(:raw_user)
      Process.unregister(:raw_user)
      Process.register(raw_user, :user)
      raw_user
    rescue
      ArgumentError -> nil
    end
    
    Process.unregister(:standard_error)
    raw_standard_error = try do
      raw_standard_error = Process.whereis(:raw_standard_error)
      Process.unregister(:raw_standard_error)
      Process.register(raw_standard_error, :standard_error)
      raw_user
    rescue
      ArgumentError -> nil
    end

    if raw_user do
      for process <- :erlang.processes(), process not in [raw_user, raw_standard_error, intercepted_user, intercepted_standard_error] do
        Process.group_leader(process, raw_user)
      end
    else
      init = :erlang.processes() |> hd
      for process <- :erlang.processes(), process not in [raw_standard_error, intercepted_user, intercepted_standard_error] do
        Process.group_leader(process, init)
      end
    end

    Process.unlink(intercepted_user)
    Process.unlink(intercepted_standard_error)

    Process.exit(intercepted_user, :kill)
    Process.exit(intercepted_standard_error, :kill)
  end

  def stream_packets(receive_packets_fn) do
    PacketStream.stream(Process.whereis(:raw_user), true)
    |> Stream.each(fn packet -> receive_packets_fn.(packet) end)
    |> Stream.run()
  end
end
