defmodule FixtureTest do
  use ExUnit.Case

  defmodule ModuleWithoutTests do
  end

  test "fixture test" do
    assert true
  end

  describe "describe with test" do
    test "fixture test" do
      assert true
    end
  end

  describe "describe without test" do
  end

  test "this will be a test in future" do
end
