defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.GetExUnitTestsInFile do
  alias ElixirLS.LanguageServer.{SourceFile, ExUnitTestTracer}
  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri], _state) do
    path = SourceFile.Path.from_uri(uri)

    case ExUnitTestTracer.get_tests(path) do
      {:ok, tests} ->
        {:ok, tests}

      {:error, reason} ->
        {:error, :server_error, "Cannot get tests in file: #{inspect(reason)}", true}
    end
  end
end
