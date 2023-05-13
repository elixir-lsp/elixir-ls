defmodule ElixirLS.Utils.PacketStream do
  @moduledoc """
  Reads from an IO device and provides a stream of incoming packets
  """

  def stream(pid, halt_on_error? \\ false) when is_pid(pid) do
    stream_pid = self()
    Task.start_link(fn ->
      ref = Process.monitor(pid)
      receive do
        {:DOWN, ^ref, :process, _pid, reason} ->
          send(stream_pid, {:exit_reason, reason})
      end
    end)

    Stream.resource(
      fn -> :ok end,
      fn _acc ->
        case read_packet(pid) do
          :eof ->
            {:halt, :ok}

          {:error, reason} ->
            # jsonrpc 2.0 requires that server responds with
            # {"jsonrpc": "2.0", "error": {"code": -32700, "message": "Parse error"}, "id": null}
            # when message fails to parse
            # instead we halt on any error - it's not worth to handle faulty clients
            {:halt, {:error, reason}}

          {:ok, packet} ->
            {[packet], :ok}
        end
      end,
      fn
        :ok ->
          :ok

        {:error, reason} ->
          "Unable to read from input device: #{inspect(reason)}"

          error_message = unless Process.alive?(pid) do
            receive do
              {:exit_reason, exit_reason} ->
                "Input device terminated: #{inspect(exit_reason)}"
            after
              500 -> "Input device terminated"
            end
          else
            "Unable to read from device: #{inspect(reason)}"
          end

          if halt_on_error? do
            if ElixirLS.Utils.WireProtocol.io_intercepted? do
              ElixirLS.Utils.WireProtocol.undo_intercept_output
            end

            IO.puts(:stderr, error_message)
            
            System.halt(1)
          else
            raise error_message
          end
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
          :eof ->
            :eof

          {:error, reason} ->
            {:error, reason}

          body ->
            case IO.iodata_length(body) do
              ^content_length ->
                # though jason docs suggest using `strings: :copy` when parts of binary may be stored
                # processes/ets in our case it does not help (as of OTP 23)
                JasonV.decode(body)

              _other ->
                {:error, :truncated}
            end
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
