defmodule ElixirLS.Debugger.BreakpointConditionTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  alias ElixirLS.Debugger.BreakpointCondition
  import ExUnit.CaptureIO

  @name BreakpointConditionTestServer
  setup do
    {:ok, pid} = BreakpointCondition.start_link(name: @name)

    {:ok,
     %{
       server: pid
     }}
  end

  test "exports check functions" do
    for i <- 0..99 do
      assert function_exported?(BreakpointCondition, :"check_#{i}", 1)
    end
  end

  describe "register" do
    test "basic" do
      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", 0)

      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_1}} ==
               BreakpointCondition.register_condition(@name, Some, [124], "c == d", 1)

      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_2}} ==
               BreakpointCondition.register_condition(@name, Other, [124], "c == d", 2)

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{
               {Other, [124]} => {2, {"c == d", 2}},
               {Some, [123]} => {0, {"a == b", 0}},
               {Some, [124]} => {1, {"c == d", 1}}
             }

      assert state.free == 3..99 |> Enum.to_list()
    end

    test "limit" do
      for i <- 0..99 do
        {:ok, _} = BreakpointCondition.register_condition(@name, Some, [i], "c == d", 1)
      end

      assert {:error, :limit_reached} ==
               BreakpointCondition.register_condition(@name, Some, [100], "c == d", 1)
    end

    test "update" do
      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", 2)

      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "c == b", 3)

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{{Some, [123]} => {0, {"c == b", 3}}}
      assert state.free == 1..99 |> Enum.to_list()
    end
  end

  describe "unregister" do
    test "basic" do
      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", 0)

      BreakpointCondition.register_hit(@name, 0)

      assert :ok == BreakpointCondition.unregister_condition(@name, Some, [123])

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{}
      assert state.hits == %{}
      assert state.free == 0..99 |> Enum.to_list()
    end

    test "idempotency" do
      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", 1)

      assert :ok == BreakpointCondition.unregister_condition(@name, Some, [123])
      assert :ok == BreakpointCondition.unregister_condition(@name, Some, [123])

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{}
      assert state.free == 0..99 |> Enum.to_list()
    end
  end

  test "has_condition?" do
    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, [123], "a == b", 1)

    assert BreakpointCondition.has_condition?(@name, Some, [123])

    refute BreakpointCondition.has_condition?(@name, Some, [124])
    refute BreakpointCondition.has_condition?(@name, Other, [123])
  end

  test "get_condition" do
    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, [123], "a == b", 1)

    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_1}} ==
             BreakpointCondition.register_condition(@name, Some, [124], "c == d", 2)

    BreakpointCondition.register_hit(@name, 1)

    assert {"a == b", 1, 0} == BreakpointCondition.get_condition(@name, 0)
    assert {"c == d", 2, 1} == BreakpointCondition.get_condition(@name, 1)
  end

  test "register_hit" do
    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, [123], "a == b", 1)

    BreakpointCondition.register_hit(@name, 0)
    assert :sys.get_state(Process.whereis(@name)).hits == %{0 => 1}
    BreakpointCondition.register_hit(@name, 0)
    assert :sys.get_state(Process.whereis(@name)).hits == %{0 => 2}
  end

  describe "evel_condition" do
    test "evals to true" do
      binding = [{:_a@0, 1}, {:_b@0, 1}]
      assert BreakpointCondition.eval_condition("a == b", binding) == true
    end

    test "evals to truthy" do
      binding = [{:_a@0, 1}]
      assert BreakpointCondition.eval_condition("a", binding) == true
    end

    test "evals to false" do
      binding = [{:_a@0, 1}, {:_b@0, 2}]
      assert BreakpointCondition.eval_condition("a == b", binding) == false
    end

    test "evals to falsy" do
      binding = [{:_a@0, nil}]
      assert BreakpointCondition.eval_condition("a", binding) == false
    end

    @tag :capture_io
    test "handles raise" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("raise ArgumentError", []) == false
      end)
    end

    @tag :capture_io
    test "handles throw" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("throw :asd", []) == false
      end)
    end

    @tag :capture_io
    test "handles exit" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("exit(:normal)", []) == false
      end)
    end
  end
end
