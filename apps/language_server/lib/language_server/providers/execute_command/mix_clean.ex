defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.MixClean do
  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([clean_deps?], _state) do
    case ElixirLS.LanguageServer.Build.clean(clean_deps?) do
      :ok -> {:ok, %{}}
      {:error, reason} -> {:error, :server_error, inspect(reason)}
    end
  end
end
