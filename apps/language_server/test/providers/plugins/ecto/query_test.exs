defmodule ElixirLS.LanguageServer.Plugins.Ecto.QueryTest do
  use ExUnit.Case, async: true

  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State
  alias ElixirLS.LanguageServer.Plugins.Ecto.Query

  defmodule Post do
    def __schema__(:association, :comments),
      do: %{related: ElixirLS.LanguageServer.Plugins.Ecto.QueryTest.Comment}
  end

  defmodule Comment do
  end

  test "extract_bindings includes join associations" do
    prefix =
      "from p in ElixirLS.LanguageServer.Plugins.Ecto.QueryTest.Post, " <>
        "join: c in assoc(p, :comments), where: c"

    info = Source.which_func(prefix, %Binding{})

    assert %{
             "p" => %{type: Post},
             "c" => %{type: Comment}
           } = Query.extract_bindings(prefix, info, %State.Env{}, %ElixirSense.Core.Metadata{})
  end
end
