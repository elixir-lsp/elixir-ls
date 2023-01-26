defmodule ElixirLS.LanguageServer.Experimental.Log do
  defmacro log_and_time(label, do: block) do
    quote do
      require Logger

      {time_in_us, result} =
        :timer.tc(fn ->
          unquote(block)
        end)

      Logger.info("#{unquote(label)} took #{Float.round(time_in_us / 1000, 2)}ms")
      result
    end
  end
end
