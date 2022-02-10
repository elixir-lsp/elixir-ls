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
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", nil, 0)

      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_1}} ==
               BreakpointCondition.register_condition(@name, Some, [124], "c == d", "asd", 1)

      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_2}} ==
               BreakpointCondition.register_condition(@name, Other, [124], "c == d", nil, 2)

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{
               {Other, [124]} => {2, {"c == d", nil, 2}},
               {Some, [123]} => {0, {"a == b", nil, 0}},
               {Some, [124]} => {1, {"c == d", "asd", 1}}
             }

      assert state.free == 3..99 |> Enum.to_list()
    end

    test "limit" do
      for i <- 0..99 do
        {:ok, _} = BreakpointCondition.register_condition(@name, Some, [i], "c == d", nil, 1)
      end

      assert {:error, :limit_reached} ==
               BreakpointCondition.register_condition(@name, Some, [100], "c == d", nil, 1)
    end

    test "update" do
      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", nil, 2)

      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "c == b", "xxx", 3)

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{{Some, [123]} => {0, {"c == b", "xxx", 3}}}
      assert state.free == 1..99 |> Enum.to_list()
    end
  end

  describe "unregister" do
    test "basic" do
      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", nil, 0)

      BreakpointCondition.register_hit(@name, 0)

      assert :ok == BreakpointCondition.unregister_condition(@name, Some, [123])

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{}
      assert state.hits == %{}
      assert state.free == 0..99 |> Enum.to_list()
    end

    test "idempotency" do
      assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(@name, Some, [123], "a == b", nil, 1)

      assert :ok == BreakpointCondition.unregister_condition(@name, Some, [123])
      assert :ok == BreakpointCondition.unregister_condition(@name, Some, [123])

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{}
      assert state.free == 0..99 |> Enum.to_list()
    end
  end

  test "has_condition?" do
    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, [123], "a == b", nil, 1)

    assert BreakpointCondition.has_condition?(@name, Some, [123])

    refute BreakpointCondition.has_condition?(@name, Some, [124])
    refute BreakpointCondition.has_condition?(@name, Other, [123])
  end

  test "get_condition" do
    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, [123], "a == b", nil, 1)

    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_1}} ==
             BreakpointCondition.register_condition(@name, Some, [124], "c == d", "xxx", 2)

    BreakpointCondition.register_hit(@name, 1)

    assert {"a == b", nil, 1, 0} == BreakpointCondition.get_condition(@name, 0)
    assert {"c == d", "xxx", 2, 1} == BreakpointCondition.get_condition(@name, 1)
  end

  test "register_hit" do
    assert {:ok, {ElixirLS.Debugger.BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, [123], "a == b", nil, 1)

    BreakpointCondition.register_hit(@name, 0)
    assert :sys.get_state(Process.whereis(@name)).hits == %{0 => 1}
    BreakpointCondition.register_hit(@name, 0)
    assert :sys.get_state(Process.whereis(@name)).hits == %{0 => 2}
  end

  describe "evel_condition" do
    test "evals to true" do
      binding = [{:a, 1}, {:b, 1}]
      assert BreakpointCondition.eval_condition("a == b", binding) == true
    end

    test "evals to truthy" do
      binding = [{:a, 1}]
      assert BreakpointCondition.eval_condition("a", binding) == true
    end

    test "evals to false" do
      binding = [{:a, 1}, {:b, 2}]
      assert BreakpointCondition.eval_condition("a == b", binding) == false
    end

    test "evals to falsy" do
      binding = [{:a, nil}]
      assert BreakpointCondition.eval_condition("a", binding) == false
    end

    test "handles raise" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("raise ArgumentError", []) == false
      end)
    end

    test "handles throw" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("throw :asd", []) == false
      end)
    end

    test "handles exit" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("exit(:normal)", []) == false
      end)
    end
  end

  describe "interpolate" do
    test "basic" do
      assert BreakpointCondition.interpolate("", []) == ""
      assert BreakpointCondition.interpolate("abc", []) == "abc"
    end

    test "escape sequences" do
      assert BreakpointCondition.interpolate("\\{", []) == "{"
      assert BreakpointCondition.interpolate("\\}", []) == "}"
    end

    test "substitute variable" do
      assert BreakpointCondition.interpolate("abc{myvar}cde", myvar: "123") == "abc123cde"
      assert BreakpointCondition.interpolate("abc{myvar}cde", myvar: 123) == "abc123cde"
    end

    test "escape sequence within substitution" do
      assert BreakpointCondition.interpolate("abc{inspect(%\\{\\})}cde", []) == "abc%{}cde"
    end

    test "invalid" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.interpolate("abc{myvar{cde", []) == "abc"
        assert BreakpointCondition.interpolate("abc{myvarcde", myvar: 123) == "abc"
      end)
    end

    test "error in substitution" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.interpolate("abc{myvar}cde", []) == "abccde"
        assert BreakpointCondition.interpolate("abc{self()}cde", myvar: 123) == "abccde"
        assert BreakpointCondition.interpolate("abc{throw :error}cde", myvar: 123) == "abccde"
      end)
    end
  end
end
