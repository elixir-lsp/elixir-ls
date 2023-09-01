defmodule ElixirLS.Debugger.BindingTest do
  use ElixirLS.Utils.MixTest.Case, async: true
  alias ElixirLS.Debugger.Binding

  test "get_elixir_variable" do
    assert :asd == Binding.get_elixir_variable(:_asd@1)
    assert :asd == Binding.get_elixir_variable(:_asd@123)
  end

  test "get_number" do
    assert 1 == Binding.get_number(:_asd@1)
    assert 123 == Binding.get_number(:_asd@123)
  end

  describe "to_elixir_variable_names" do
    test "empty" do
      assert [] == Binding.to_elixir_variable_names([])
    end

    test "single value" do
      assert [{:asd, "a"}] == Binding.to_elixir_variable_names([{:_asd@1, "a"}])
    end

    test "multiple values" do
      assert [{:asd, "a"}, {:qwe, "b"}] ==
               Binding.to_elixir_variable_names([{:_asd@1, "a"}, {:_qwe@1, "b"}])
    end

    test "multiple versions" do
      assert [{:asd, "b"}] ==
               Binding.to_elixir_variable_names([{:_asd@1, "a"}, {:_asd@12, "b"}, {:_asd@11, "c"}])
    end

    test "filter _" do
      assert [] == Binding.to_elixir_variable_names([{:_, "a"}])
    end

    test "filter _ versioned" do
      assert [] == Binding.to_elixir_variable_names([{:_@123, "a"}])
    end

    test "filter underscored variables" do
      assert [] == Binding.to_elixir_variable_names([{:__asd@123, "a"}])
    end
  end
end
