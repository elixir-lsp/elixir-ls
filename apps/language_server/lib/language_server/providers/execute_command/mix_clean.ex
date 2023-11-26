defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.MixClean do
  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([clean_deps?], state) do
    case ElixirLS.LanguageServer.Build.clean(state.project_dir, clean_deps?) do
      :ok -> {:ok, %{}}
      {:error, reason} -> {:error, :server_error, "Mix clean failed: #{inspect(reason)}", true}
    end
  end
end
