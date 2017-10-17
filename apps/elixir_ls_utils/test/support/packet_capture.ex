defmodule ElixirLS.Utils.PacketCapture do
  @moduledoc """
  When set as group leader, captures packets output and sends them to another process

  This is useful in tests so we can use macros like `assert_receive` to test that packets are being
  output correctly.
  """

  use GenServer

  ## Client API

  def start_link(parent) do
    GenServer.start_link(__MODULE__, parent)
  end

  ## Server Callbacks

  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, chars}}, parent) do
    handle_output(to_string(chars), from, reply_as, parent)
  end

  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, module, fun, args}}, parent) do
    handle_output(to_string(module.apply(fun, args)), from, reply_as, parent)
  end

  def handle_info(msg, s) do
    super(msg, s)
  end

  defp handle_output(str, from, reply_as, parent) do
    case extract_packet(str) do
      nil ->
        :ok
      packet ->
        send(parent, packet)
    end

    send(from, {:io_reply, reply_as, :ok})
    {:noreply, parent}
  end

  defp extract_packet(str) do
    with [_header, body] <- String.split(str, "\r\n\r\n", parts: 2),
         {:ok, packet} <- Poison.decode(body)
      do
        packet
      else
        _ -> nil
    end
  end
end
