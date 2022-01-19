defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.Restart do
  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute(_args, _state) do
    System.halt(0)
  end
end
