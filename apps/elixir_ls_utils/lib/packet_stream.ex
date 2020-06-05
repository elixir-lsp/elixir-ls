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
          {:error, reason} -> {:halt, {:error, reason}}
          packet -> {[packet], :ok}
        end
      end,
      fn
        :ok -> :ok
        {:error, reason} ->
          IO.warn("Unable to read from device: #{inspect(reason)}")
      end
    )
  end

  defp read_packet(pid) do
    header = read_header(pid)

    case header do
      :eof -> :eof
      {:error, reason} -> {:error, reason}
      header -> read_body(pid, header)
    end
  end

  defp read_header(pid, header \\ %{}) do
    line = IO.binread(pid, :line)

    case line do
      :eof -> :eof
      {:error, reason} -> {:error, reason}
      line ->
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

    case body do
      :eof -> :eof
      {:error, reason} -> {:error, reason}
      body -> JasonVendored.decode!(body)
    end
  end
end
