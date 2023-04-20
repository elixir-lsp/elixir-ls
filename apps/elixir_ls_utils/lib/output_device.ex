defmodule ElixirLS.Utils.OutputDevice do
  @moduledoc """
  Intercepts IO request messages and forwards them to the Output server to be sent as events to
  the IDE. Implements [Erlang I/O Protocol](https://erlang.org/doc/apps/stdlib/io_protocol.html)
  """

  @opts binary: true, encoding: :latin1

  ## Client API

  def start_link(device, output_fn) do
    Task.start_link(fn -> loop({device, output_fn}) end)
  end

  def child_spec(arguments) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, arguments},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def get_opts, do: @opts

  ## Implementation

  defp loop(state) do
    receive do
      {:io_request, from, reply_as, request} ->
        result = io_request(request, state, reply_as)
        send(from, {:io_reply, reply_as, result})

        loop(state)
    end
  end

  defp send_to_output(encoding, characters, {_device, output_fn}) do
    # convert to unicode binary if necessary
    case wrap_characters_to_binary(characters, encoding) do
      binary when is_binary(binary) ->
        output_fn.(binary)

      _ ->
        {:error, :put_chars}
    end
  end

  defp io_request({:put_chars, encoding, characters}, state, _reply_as) do
    send_to_output(encoding, characters, state)
  end

  defp io_request({:put_chars, encoding, module, func, args}, state, _reply_as) do
    # apply mfa to get binary or list
    # return error in other cases
    try do
      case apply(module, func, args) do
        characters when is_list(characters) or is_binary(characters) ->
          send_to_output(encoding, characters, state)

        _ ->
          {:error, :put_chars}
      end
    catch
      _, _ -> {:error, :put_chars}
    end
  end

  defp io_request({:requests, list}, state, reply_as) do
    # process request sequentially until error or end of data
    # return last result
    case io_requests(list, {:ok, :ok}, state, reply_as) do
      :ok -> :ok
      {:error, error} -> {:error, error}
      other -> {:ok, other}
    end
  end

  defp io_request(:getopts, _state, _reply_as) do
    @opts
  end

  defp io_request({:setopts, new_opts}, _state, _reply_as) do
    validate_otps(new_opts, {:ok, 0})
  end

  defp io_request(unknown, {device, _output_fn}, reply_as) do
    # forward requests to underlying device
    send(device, {:io_request, self(), reply_as, unknown})

    receive do
      {:io_reply, ^reply_as, reply} -> reply
    end
  end

  defp io_requests(_, {:error, error}, _, _), do: {:error, error}

  defp io_requests([request | rest], _, state, reply_as) do
    result = io_request(request, state, reply_as)
    io_requests(rest, result, state, reply_as)
  end

  defp io_requests([], result, _, _), do: result

  defp wrap_characters_to_binary(bin, :unicode) when is_binary(bin), do: bin

  defp wrap_characters_to_binary(chars, from) do
    # :unicode.characters_to_binary may throw, return error or incomplete result
    try do
      case :unicode.characters_to_binary(chars, from, :unicode) do
        bin when is_binary(bin) ->
          bin

        _ ->
          :error
      end
    catch
      _, _ -> :error
    end
  end

  defp validate_otps([opt | rest], {:ok, acc}) do
    validate_otps(rest, opt_valid?(opt, acc))
  end

  defp validate_otps([], {:ok, 2}), do: :ok
  defp validate_otps(_, _acc), do: {:error, :enotsup}

  defp opt_valid?(:binary, acc), do: {:ok, acc + 1}
  defp opt_valid?({:binary, true}, acc), do: {:ok, acc + 1}
  defp opt_valid?({:encoding, :unicode}, acc), do: {:ok, acc + 1}
  defp opt_valid?(_opt, _acc), do: :error
end
