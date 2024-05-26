defmodule Logger.Backends.JsonRpc do
  @moduledoc ~S"""
  A logger backend that logs messages by sending them via LSP ‘window/logMessage’.

  ## Options

    * `:level` - the level to be logged by this backend.
      Note that messages are filtered by the general
      `:level` configuration for the `:logger` application first.

    * `:format` - the format message used to print logs.
      Defaults to: `"$message"`.
      It may also be a `{module, function}` tuple that is invoked
      with the log level, the message, the current timestamp and
      the metadata and must return `t:IO.chardata/0`. See
      `Logger.Formatter`.

    * `:metadata` - the metadata to be printed by `$metadata`.
      Defaults to an empty list (no metadata).
      Setting `:metadata` to `:all` prints all metadata. See
      the "Metadata" section for more information.

  """

  @behaviour :gen_event

  defstruct group_leader: nil,
            default_group_leader: nil,
            format: nil,
            level: nil,
            metadata: nil

  @impl true
  def init(__MODULE__) do
    config = Application.get_env(:logger, __MODULE__)

    {:ok, init(config, %__MODULE__{})}
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    config = configure_merge(Application.get_env(:logger, __MODULE__), opts)
    {:ok, init(config, %__MODULE__{})}
  end

  @impl true
  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  def handle_call({:set_group_leader, pid}, state) do
    Process.monitor(pid)
    default_group_leader = Process.group_leader()
    Process.group_leader(self(), pid)
    {:ok, :ok, %{state | group_leader: pid, default_group_leader: default_group_leader}}
  end

  @impl true
  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    %{level: log_level} = state

    {:erl_level, level} = List.keyfind(md, :erl_level, 0, {:erl_level, level})

    cond do
      not meet_level?(level, log_level) ->
        {:ok, state}

      true ->
        {:ok, log_event(level, msg, ts, md, state)}
    end
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  @impl true
  def handle_info(
        {:DOWN, _, :process, pid, _},
        state = %{group_leader: pid, default_group_leader: default_group_leader}
      ) do
    Process.group_leader(self(), default_group_leader)
    {:ok, %{state | group_leader: nil}}
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
    config = configure_merge(Application.get_env(:logger, __MODULE__), options)
    Application.put_env(:logger, __MODULE__, config)
    init(config, state)
  end

  defp init(config, state) do
    level = Keyword.get(config, :level)
    format = Logger.Formatter.compile(Keyword.get(config, :format))
    metadata = Keyword.get(config, :metadata, []) |> configure_metadata()

    %{
      state
      | format: format,
        metadata: metadata,
        level: level
    }
  end

  defp configure_metadata(:all), do: :all
  defp configure_metadata(metadata), do: Enum.reverse(metadata)

  defp configure_merge(env, options) do
    Keyword.merge(env, options, fn
      _, _v1, v2 -> v2
    end)
  end

  defp log_event(level, msg, ts, md, state) do
    output = format_event(level, msg, ts, md, state) |> IO.chardata_to_string()
    ElixirLS.LanguageServer.JsonRpc.log_message(elixir_log_level_to_lsp(level), output)

    state
  end

  defp elixir_log_level_to_lsp(:debug), do: :log
  defp elixir_log_level_to_lsp(:info), do: :info
  defp elixir_log_level_to_lsp(:notice), do: :info
  defp elixir_log_level_to_lsp(:warning), do: :warning
  defp elixir_log_level_to_lsp(:warn), do: :warning
  defp elixir_log_level_to_lsp(:error), do: :error
  defp elixir_log_level_to_lsp(:critical), do: :error
  defp elixir_log_level_to_lsp(:alert), do: :error
  defp elixir_log_level_to_lsp(:emergency), do: :error

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

  # Erlang/OTP log handler
  def log(%{level: level} = event, config) do
    %{formatter: {formatter_mod, formatter_config}} = config
    chardata = formatter_mod.format(event, formatter_config)
    ElixirLS.LanguageServer.JsonRpc.log_message(elixir_log_level_to_lsp(level), chardata)
  end

  def handler_config() do
    %{formatter: Logger.default_formatter(colors: [enabled: false], format: "$message")}
  end
end
