defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.Restart do
  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute(_args, _state) do
    Task.start(fn ->
      Logger.info("ElixirLS will restart")
      Process.sleep(1000)
      System.stop(0)
    end)
  end
end
