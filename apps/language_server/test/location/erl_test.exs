defmodule ElixirLS.LanguageServer.Location.ErlTest do
  use ExUnit.Case
  alias ElixirLS.LanguageServer.Location.Erl

  @moduledoc """
  Unit tests for the Location.Erl module.
  """

  setup do
    erl_file = Path.join(__DIR__, "sample_erl")

    {:ok, erl_file: erl_file}
  end

  describe "find_module_position_in_erl_file/2" do
    test "finds the module declaration position", %{erl_file: erl_file} do
      expected_range = {{7, 9}, {7, 19}}

      assert Erl.find_module_range(erl_file, :sample_erl) == expected_range
    end

    test "returns nil for non-existent module", %{erl_file: erl_file} do
      assert Erl.find_module_range(erl_file, :non_existent) == nil
    end
  end

  describe "find_type_position_in_erl_file/2" do
    test "finds the type definition position", %{erl_file: erl_file} do
      expected_range = {{9, 9}, {9, 16}}

      assert Erl.find_type_range(erl_file, :my_type) == expected_range
    end

    test "returns nil for non-existent type", %{erl_file: erl_file} do
      assert Erl.find_type_range(erl_file, :non_existent_type) == nil
    end
  end

  describe "find_fun_range/2" do
    test "finds the function definition position", %{erl_file: erl_file} do
      expected_range = {{11, 1}, {11, 12}}

      assert Erl.find_fun_range(erl_file, :my_function) == expected_range
    end

    test "returns nil for non-existent function", %{erl_file: erl_file} do
      assert Erl.find_fun_range(erl_file, :non_existent_function) == nil
    end
  end
end
