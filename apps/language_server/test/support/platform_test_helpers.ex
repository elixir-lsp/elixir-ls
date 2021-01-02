defmodule ElixirLS.LanguageServer.Test.PlatformTestHelpers do
  def maybe_convert_path_separators(path) do
    if is_windows() do
      String.replace(path, ~r/\//, "\\")
    else
      path
    end
  end

  def is_windows() do
    case :os.type() do
      {:win32, _} -> true
      _ -> false
    end
  end
end