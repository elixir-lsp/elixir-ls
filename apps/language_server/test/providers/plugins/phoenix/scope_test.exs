defmodule ElixirLS.LanguageServer.Plugins.Phoenix.ScopeTest do
  use ExUnit.Case
  alias ElixirSense.Core.Binding
  alias ElixirLS.LanguageServer.Plugins.Phoenix.Scope

  describe "within_scope/1" do
    test "returns true and nil alias" do
      buffer = """
        scope "/" do
          get "/",
      """

      assert {true, nil} = Scope.within_scope(buffer)
    end

    test "returns true and alias when passing alias as option" do
      buffer = """
        scope "/", alias: ExampleWeb do
          get "/",
      """

      assert {true, ExampleWeb} = Scope.within_scope(buffer)
    end

    test "returns true and alias when passing alias as second parameter" do
      buffer = """
        scope "/", ExampleWeb do
          get "/",
      """

      assert {true, ExampleWeb} = Scope.within_scope(buffer)
    end

    test "returns true and alias when nested within other scopes" do
      _define_existing_atom = ExampleWeb.Admin
      _define_existing_atom = Admin

      buffer = """
        scope "/", ExampleWeb do
          scope "/admin", Admin do
            get "/",
      """

      assert {true, ExampleWeb.Admin} = Scope.within_scope(buffer)
    end

    test "can expand module attributes" do
      buffer = """
      defmodule ExampleWeb.Router do
        import Phoenix.Router
        @web_prefix ExampleWweb

        scope "/", @web_prefix do
          get "/",
      """

      binding = %Binding{
        structs: %{},
        vars: [],
        attributes: [
          %ElixirSense.Core.State.AttributeInfo{
            name: :web_prefix,
            positions: [{4, 5}],
            type: {:atom, ExampleWeb}
          }
        ],
        module: ExampleWeb.Router,
        specs: %{},
        types: %{},
        mods_funs_to_positions: %{}
      }

      assert {true, ExampleWeb} = Scope.within_scope(buffer, binding)
    end

    test "can expand variables" do
      buffer = """
      defmodule ExampleWeb.Router do
        import Phoenix.Router
        web_prefix = ExampleWweb

        scope "/", web_prefix do
          get "/",
      """

      binding = %Binding{
        structs: %{},
        vars: [
          %ElixirSense.Core.State.VarInfo{
            name: :web_prefix,
            positions: [{5, 5}],
            scope_id: 2,
            type: {:atom, ExampleWeb}
          }
        ],
        attributes: [],
        module: ExampleWeb.Router,
        specs: %{},
        types: %{},
        mods_funs_to_positions: %{}
      }

      assert {true, ExampleWeb} = Scope.within_scope(buffer, binding)
    end

    test "returns false" do
      buffer = "get \"\\\" ,"

      assert {false, nil} = Scope.within_scope(buffer)
    end
  end
end
