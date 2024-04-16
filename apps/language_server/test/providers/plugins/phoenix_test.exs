defmodule ElixirLS.LanguageServer.Plugins.PhoenixTest do
  use ExUnit.Case

  def cursors(text) do
    {_, cursors} =
      ElixirSense.Core.Source.walk_text(text, {false, []}, fn
        "#", rest, _, _, {_comment?, cursors} ->
          {rest, {true, cursors}}

        "\n", rest, _, _, {_comment?, cursors} ->
          {rest, {false, cursors}}

        "^", rest, line, col, {true, cursors} ->
          {rest, {true, [%{line: line - 1, col: col} | cursors]}}

        _, rest, _, _, acc ->
          {rest, acc}
      end)

    Enum.reverse(cursors)
  end

  def suggestions(buffer, cursor) do
    ElixirLS.LanguageServer.Providers.Completion.Suggestion.suggestions(
      buffer,
      cursor.line,
      cursor.col
    )
  end

  @moduletag requires_elixir_1_14: true
  describe "suggestions/4" do
    test "overrides with controllers for phoenix_route_funcs, when in the second parameter" do
      buffer = """
      defmodule ExampleWeb.Router do
        import Phoenix.Router

        get "/", P
        #         ^
      end
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [
               %{
                 type: :generic,
                 kind: :class,
                 label: "ExampleWeb.PageController",
                 insert_text: "ExampleWeb.PageController",
                 detail: "Phoenix controller"
               }
             ] = result
    end

    test "do not prepend alias defined within Phoenix `scope` functions" do
      _define_existing_atom = ExampleWeb

      buffer = """
        defmodule ExampleWeb.Router do
          import Phoenix.Router

          scope "/", ExampleWeb do
            get "/", P
            #         ^
          end
        end
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [
               %{
                 type: :generic,
                 kind: :class,
                 label: "ExampleWeb.PageController",
                 insert_text: "PageController",
                 detail: "Phoenix controller"
               }
             ] = result
    end

    test "overrides with action suggestions for phoenix_route_funcs, when in the third parameter" do
      buffer = """
      defmodule ExampleWeb.Router do
        import Phoenix.Router

        get "/", ExampleWeb.PageController, :
        #                                    ^
      end
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [
               %{
                 detail: "Phoenix action",
                 insert_text: "home",
                 kind: :function,
                 label: ":home",
                 type: :generic
               }
             ] = result
    end

    test "overrides with action suggestions even when inside scope" do
      buffer = """
      defmodule ExampleWeb.Router do
        import Phoenix.Router

        scope "/", ExampleWeb do
          get "/", PageController, :
          #                         ^
        end
      end
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [
               %{
                 detail: "Phoenix action",
                 insert_text: "home",
                 kind: :function,
                 label: ":home",
                 type: :generic
               }
             ] = result
    end

    test "ignores for non-phoenix_route_funcs" do
      buffer = """
      defmodule ExampleWeb.Router do
        import Phoenix.Router

        something_else "/", P
        #                    ^
      end
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      refute Enum.find(result, &(&1[:detail] == "Phoenix controller"))
    end
  end
end
