defmodule Logger.Backends.JsonRpc do
  @moduledoc ~S"""
  A logger backend that logs messages by sending them via ‘window/logMessage’.

  ## Options

    * `:level` - the level to be logged by this backend.
      Note that messages are filtered by the general
      `:level` configuration for the `:logger` application first.

    * `:format` - the format message used to print logs.
      Defaults to: `"\n$time $metadata[$level] $message\n"`.
      It may also be a `{module, function}` tuple that is invoked
      with the log level, the message, the current timestamp and
      the metadata and must return `t:IO.chardata/0`. See
      `Logger.Formatter`.

    * `:metadata` - the metadata to be printed by `$metadata`.
      Defaults to an empty list (no metadata).
      Setting `:metadata` to `:all` prints all metadata. See
      the "Metadata" section for more information.

    * `:device` - the device to log error messages to. Defaults to
      `:user` but can be changed to something else such as `:standard_error`.

  """

  @behaviour :gen_event

  defstruct device: nil,
            format: nil,
            level: nil,
            metadata: nil,
            output: nil,
            ref: nil

  @impl true
  def init(:json_rpc) do
    config = Application.get_env(:logger, :json_rpc)
    device = Keyword.get(config, :device, :user)

    if Process.whereis(device) do
      {:ok, init(config, %__MODULE__{})}
    else
      {:error, :ignore}
    end
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    config = configure_merge(Application.get_env(:logger, :json_rpc), opts)
    {:ok, init(config, %__MODULE__{})}
  end

  @impl true
  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  @impl true
  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    %{level: log_level, ref: ref} = state

    {:erl_level, level} = List.keyfind(md, :erl_level, 0, {:erl_level, level})

    cond do
      not meet_level?(level, log_level) ->
        {:ok, state}

      is_nil(ref) ->
        {:ok, log_event(level, msg, ts, md, state)}
    end
  end

  def handle_event(:flush, state) do
    {:ok, flush(state)}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  @impl true
  def handle_info({:io_reply, ref, msg}, %{ref: ref} = state) do
    {:ok, handle_io_reply(msg, state)}
  end

  def handle_info({:DOWN, ref, _, pid, reason}, %{ref: ref}) do
    raise "device #{inspect(pid)} exited: " <> Exception.format_exit(reason)
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  @impl true
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  ## Helpers

  defp meet_level?(_lvl, nil), do: true

  defp meet_level?(lvl, min) do
    Logger.compare_levels(lvl, min) != :lt
  end

  defp configure(options, state) do
    config = configure_merge(Application.get_env(:logger, :json_rpc), options)
    Application.put_env(:logger, :json_rpc, config)
    init(config, state)
  end

  defp init(config, state) do
    level = Keyword.get(config, :level)
    device = Keyword.get(config, :device, :user)
    format = Logger.Formatter.compile(Keyword.get(config, :format))
    metadata = Keyword.get(config, :metadata, []) |> configure_metadata()

    %{
      state
      | format: format,
        metadata: metadata,
        level: level,
        device: device
    }
  end

  defp configure_metadata(:all), do: :all
  defp configure_metadata(metadata), do: Enum.reverse(metadata)

  defp configure_merge(env, options) do
    Keyword.merge(env, options, fn
      _, _v1, v2 -> v2
    end)
  end

  defp log_event(level, msg, ts, md, %{device: device} = state) do
    output = format_event(level, msg, ts, md, state)
    %{state | ref: async_io(device, output), output: output}
  end

  defp async_io(name, output) when is_atom(name) do
    case Process.whereis(name) do
      device when is_pid(device) ->
        async_io(device, output)

      nil ->
        raise "no device registered with the name #{inspect(name)}"
    end
  end

  defp async_io(device, output) when is_pid(device) do
    ref = Process.monitor(device)
    send(device, {:io_request, self(), ref, {:put_chars, :unicode, output}})
    ref
  end

  defp await_io(%{ref: nil} = state), do: state

  defp await_io(%{ref: ref} = state) do
    receive do
      {:io_reply, ^ref, :ok} ->
        handle_io_reply(:ok, state)

      {:io_reply, ^ref, error} ->
        handle_io_reply(error, state)
        |> await_io()

      {:DOWN, ^ref, _, pid, reason} ->
        raise "device #{inspect(pid)} exited: " <> Exception.format_exit(reason)
    end
  end

  defp format_event(level, msg, ts, md, state) do
    %{format: format, metadata: keys} = state

    format
    |> Logger.Formatter.format(level, msg, ts, take_metadata(md, keys))
  end

  defp take_metadata(metadata, :all) do
    metadata
  end

  defp take_metadata(metadata, keys) do
    Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error -> acc
      end
    end)
  end

  defp retry_log(error, %{device: device, ref: ref, output: dirty} = state) do
    Process.demonitor(ref, [:flush])

    try do
      :unicode.characters_to_binary(dirty)
    rescue
      ArgumentError ->
        clean = ["failure while trying to log malformed data: ", inspect(dirty), ?\n]
        %{state | ref: async_io(device, clean), output: clean}
    else
      {_, good, bad} ->
        clean = [good | Logger.Formatter.prune(bad)]
        %{state | ref: async_io(device, clean), output: clean}

      _ ->
        # A well behaved IO device should not error on good data
        raise "failure while logging json_rpc messages: " <> inspect(error)
    end
  end

  defp flush(%{ref: nil} = state), do: state

  defp flush(state) do
    state
    |> await_io()
    |> flush()
  end
end
