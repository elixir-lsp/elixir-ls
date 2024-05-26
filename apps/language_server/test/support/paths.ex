defmodule ElixirLS.LanguageServer.Test.Paths do
  alias ElixirLS.LanguageServer.SourceFile

  def to_native_separators(path) do
    if SourceFile.Path.windows?() do
      String.replace(path, ~r/\//, "\\")
    else
      path
    end
  end
end
