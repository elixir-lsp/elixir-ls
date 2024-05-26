defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.GetExUnitTestsInFile do
  alias ElixirLS.LanguageServer.{SourceFile, ExUnitTestTracer}
  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri], _state) do
    if Version.match?(System.version(), ">= 1.13.0-dev") do
      path = SourceFile.Path.from_uri(uri)

      case ExUnitTestTracer.get_tests(path) do
        {:ok, tests} ->
          {:ok, tests}

        {:error, _reason} ->
          # TODO catch only Compile and Syntax errors?
          {:ok, []}
      end
    else
      {:ok, []}
    end
  end
end
