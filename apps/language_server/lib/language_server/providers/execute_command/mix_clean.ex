defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.MixClean do
  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute(_, %{project_dir: nil}) do
    {:error, :invalid_request, "No mix project", false}
  end

  def execute([clean_deps?], %{project_dir: project_dir}) do
    case ElixirLS.LanguageServer.Build.clean(project_dir, clean_deps?) do
      :ok -> {:ok, %{}}
      :no_mixfile -> {:error, :invalid_request, "No mix.exs in project dir", false}
      {:error, reason} -> {:error, :request_failed, "Mix clean failed: #{inspect(reason)}", true}
    end
  end
end
