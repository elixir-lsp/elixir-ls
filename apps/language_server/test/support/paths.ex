defmodule ElixirLS.LanguageServer.Test.Paths do
  alias ElixirLS.LanguageServer.SourceFile

  def join_normalize(path_elements) when is_list(path_elements) do
    path_elements
    |> Path.join()
    |> normalize()
  end

  def join_normalize(first, second) do
    first
    |> Path.join(second)
    |> normalize()
  end

  def normalize(path) when is_binary(path) do
    path
    |> SourceFile.Path.to_uri()
    |> SourceFile.Path.from_uri()
  end

  def maybe_fix_separators(path) do
    if SourceFile.Path.windows?() do
      String.replace(path, ~r/\//, "\\")
    else
      path
    end
  end
end
