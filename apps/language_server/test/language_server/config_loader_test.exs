defmodule ElixirLS.LanguageServer.ConfigLoaderTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.ConfigLoader

  describe "load/2" do
    test "dialyzer enabled is respected" do
      changed_settings = %{
        "dialyzerEnabled" => false
      }

      prev_settings = %{}

      assert {:ok, %{dialyzer_enabled: false}, _} =
               ConfigLoader.load(prev_settings, changed_settings)
    end
  end
end
