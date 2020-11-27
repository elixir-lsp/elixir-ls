defmodule ElixirLS.LanguageServer.Test.FixtureHelpers do
  def get_path(file) do
    Path.join([__DIR__, "fixtures", file]) |> Path.expand()
  end
end
