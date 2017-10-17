defmodule ElixirLS.LanguageServer.LoggerBackend do
  @moduledoc """
  Logger backend that outputs messages via Language Server Protocol's `"window/logMessage"` event
  """
  alias ElixirLS.LanguageServer.JsonRpc

  @behaviour :gen_event

  ## Server callbacks

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end

  def handle_event({level, _gl, {Logger, msg, _ts, _md}}, %{level: min_level} = state) do
    if (is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt) do
      msg = to_string(msg)
      type =
        case level do
          :debug -> :log
          :warn -> :warning
          _ -> level
        end

      JsonRpc.log_message(type, msg)
    end

    {:ok, state}
  end

  def handle_event(:flush, state) do
    # We're not buffering anything so this is a no-op
    {:ok, state}
  end

  ## Helpers

  defp configure(name, opts) do
    state = %{name: nil, level: nil}
    configure(name, opts, state)
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level = Keyword.get(opts, :level)

    %{state | name: name, level: level}
  end
end
