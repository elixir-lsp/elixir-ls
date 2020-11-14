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
          {:ok, packet} -> {[packet], :ok}
        end
      end,
      fn
        :ok ->
          :ok

        {:error, reason} ->
          IO.warn("Unable to read from device: #{inspect(reason)}")
      end
    )
  end

  defp read_packet(pid) do
    header =
      read_header(pid)
      |> validate_content_type

    case header do
      :eof -> :eof
      {:error, reason} -> {:error, reason}
      header -> read_body(pid, header)
    end
  end

  defp read_header(pid, header \\ %{}) do
    line = IO.binread(pid, :line)

    case line do
      :eof ->
        :eof

      {:error, reason} ->
        {:error, reason}

      line ->
        line = String.trim(line)

        if line == "" do
          header
        else
          case String.split(line, ": ") do
            [key, value] ->
              read_header(pid, Map.put(header, key, value))

            _ ->
              {:error, :invalid_header}
          end
        end
    end
  end

  defp read_body(pid, header) do
    case get_content_length(header) do
      {:ok, content_length} ->
        case IO.binread(pid, content_length) do
          :eof -> :eof
          {:error, reason} -> {:error, reason}
          body -> JasonVendored.decode(body)
        end

      other ->
        other
    end
  end

  def get_content_length(%{"Content-Length" => content_length_str}) do
    case Integer.parse(content_length_str) do
      {l, ""} when l >= 0 -> {:ok, l}
      _ -> {:error, :invalid_content_length}
    end
  end

  def get_content_length(_), do: {:error, :invalid_content_length}

  @default_mime_type "application/vscode-jsonrpc"
  @default_charset "utf-8"

  defp get_content_type(%{"Content-Type" => content_type}) do
    case String.split(content_type, ";") do
      [mime_type] ->
        {mime_type |> String.trim() |> String.downcase(), @default_charset}

      [mime_type | parameters] ->
        maybe_charset =
          for parameter <- parameters,
              trimmed = parameter |> String.trim(),
              trimmed |> String.starts_with?("charset="),
              "charset=" <> value = trimmed,
              do: value |> String.replace("\"", "") |> String.downcase()

        charset =
          case maybe_charset |> Enum.at(0) do
            nil -> @default_charset
            # backwards compatibility
            "utf8" -> @default_charset
            other -> other
          end

        {mime_type |> String.trim() |> String.downcase(), charset}
    end
  end

  defp get_content_type(%{}), do: {@default_mime_type, @default_charset}

  def validate_content_type(header) when is_map(header) do
    if get_content_type(header) == {@default_mime_type, @default_charset} do
      header
    else
      {:error, :not_supported_content_type}
    end
  end

  def validate_content_type(other), do: other
end
