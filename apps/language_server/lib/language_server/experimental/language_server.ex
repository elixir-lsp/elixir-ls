defmodule ElixirLS.LanguageServer.Experimental.LanguageServer do
  require Logger

  @type uri :: String.t()

  def handler_state(method) do
    if enabled?() do
      Map.get(handler_states(), method, :ignored)
    else
      :ignored
    end
  end

  @enabled Application.compile_env(:language_server, :enable_experimental_server, false)

  def persist_enabled_state do
    set_enabled(@enabled)
  end

  def set_enabled(value) do
    if :persistent_term.get(:experimental_enabled?, nil) == nil do
      spawn(fn ->
        Process.sleep(5000)

        if value do
          handled_messages =
            Enum.map_join(handler_states(), "\n", fn {method, access} ->
              "\t#{method}: #{access}"
            end)

          "Experimental server is enabled. handling the following messages #{handled_messages}"
        else
          "Experimental server is disabled."
        end
        |> Logger.info()
      end)

      :persistent_term.put(:experimental_enabled?, value)
    end
  end

  def enabled? do
    :persistent_term.get(:experimental_enabled?, false)
  end

  defp handler_states do
    case :persistent_term.get(:handler_states, nil) do
      nil ->
        load_handler_states()

      states ->
        states
    end
  end

  defp load_handler_states do
    access_map =
      Map.merge(
        LSP.Requests.__meta__(:access),
        LSP.Notifications.__meta__(:access)
      )

    :persistent_term.put(:handler_states, access_map)
    access_map
  end
end
