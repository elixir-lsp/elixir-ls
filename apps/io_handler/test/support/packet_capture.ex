defmodule ElixirLS.IOHandler.PacketCapture do
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
    case String.split(to_string(chars), "\r\n\r\n", parts: 2) do
      [_header, body] -> 
        send parent, Poison.decode!(body)
      _ ->
        nil
    end
  
    send(from, {:io_reply, reply_as, :ok})
    {:noreply, parent}
  end

  def handle_info(msg, s) do
    super(msg, s)
  end

end