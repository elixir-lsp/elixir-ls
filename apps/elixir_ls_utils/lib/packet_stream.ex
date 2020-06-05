defmodule ElixirLS.Utils.PacketStream do
  @moduledoc """
  Reads from an IO device and provides a stream of incoming packets
  """

  def stream(pid \\ Process.group_leader()) do
    if is_pid(pid) do
      :ok = :io.setopts(pid, binary: true, encoding: :latin1)
    end

    Stream.resource(
      fn -> :ok end,
      fn _acc ->
        case read_packet(pid) do
          :eof -> {:halt, :ok}
          packet -> {[packet], :ok}
        end
      end,
      fn _acc -> :ok end
    )
  end

  defp read_packet(pid) do
    header = read_header(pid)

    if header == :eof do
      :eof
    else
      read_body(pid, header)
    end
  end

  defp read_header(pid, header \\ %{}) do
    line = IO.binread(pid, :line)

    if line == :eof do
      :eof
    else
      line = String.trim(line)

      if line == "" do
        header
      else
        [key, value] = String.split(line, ": ")
        read_header(pid, Map.put(header, key, value))
      end
    end
  end

  defp read_body(pid, header) do
    %{"Content-Length" => content_length_str} = header
    body = IO.binread(pid, String.to_integer(content_length_str))

    if body == :eof do
      :eof
    else
      JasonVendored.decode!(body)
    end
  end
end
