defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.Restart do
  require Logger
  alias ElixirLS.LanguageServer.JsonRpc

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute(_args, _state) do
    {:ok, _pid} =
      Task.start(fn ->
        Logger.info("ElixirLS restart requested")

        JsonRpc.telemetry(
          "lsp_reload",
          %{
            "elixir_ls.lsp_reload_reason" => "client_request"
          },
          %{}
        )

        Process.sleep(1000)
        ElixirLS.LanguageServer.Application.restart()
      end)

    {:ok, %{}}
  end
end
