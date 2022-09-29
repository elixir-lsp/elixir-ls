defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.GetExUnitTestsInFile do
  alias ElixirLS.LanguageServer.{SourceFile, ExUnitTestTracer}
  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri], _state) do
    path = SourceFile.Path.from_uri(uri)
    # with {:ok, _} = Code.compile_file(path) do
      tests = ExUnitTestTracer.get_tests(path)
      {:ok, tests}
    # else
    #   {:error, reason} ->
    #     {:error, :server_error, inspect(reason)}
    # end
  end
end
