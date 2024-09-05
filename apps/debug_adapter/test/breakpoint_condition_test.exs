defmodule ElixirLS.DebugAdapter.BreakpointConditionTest do
  use ExUnit.Case, async: false
  alias ElixirLS.DebugAdapter.BreakpointCondition
  import ExUnit.CaptureIO

  @name BreakpointConditionTestServer
  setup do
    pid = start_supervised!({BreakpointCondition, name: @name})

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
      assert {:ok, {BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(
                 @name,
                 Some,
                 123,
                 __ENV__,
                 "a == b",
                 nil,
                 "0"
               )

      assert {:ok, {BreakpointCondition, :check_1}} ==
               BreakpointCondition.register_condition(
                 @name,
                 Some,
                 124,
                 __ENV__,
                 "c == d",
                 "asd",
                 "1"
               )

      assert {:ok, {BreakpointCondition, :check_2}} ==
               BreakpointCondition.register_condition(
                 @name,
                 Other,
                 124,
                 __ENV__,
                 "c == d",
                 nil,
                 "2"
               )

      state = :sys.get_state(Process.whereis(@name))

      assert %{
               {Other, 124} => {2, {_, "c == d", nil, "2"}},
               {Some, 123} => {0, {_, "a == b", nil, "0"}},
               {Some, 124} => {1, {_, "c == d", "asd", "1"}}
             } = state.conditions

      assert state.free == 3..99 |> Enum.to_list()
    end

    test "limit" do
      for i <- 0..99 do
        {:ok, _} =
          BreakpointCondition.register_condition(@name, Some, i, __ENV__, "c == d", nil, "1")
      end

      assert {:error, :limit_reached} ==
               BreakpointCondition.register_condition(
                 @name,
                 Some,
                 100,
                 __ENV__,
                 "c == d",
                 nil,
                 "1"
               )
    end

    test "update" do
      assert {:ok, {BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(
                 @name,
                 Some,
                 123,
                 __ENV__,
                 "a == b",
                 nil,
                 "2"
               )

      assert {:ok, {BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(
                 @name,
                 Some,
                 123,
                 __ENV__,
                 "c == b",
                 "xxx",
                 "3"
               )

      state = :sys.get_state(Process.whereis(@name))

      assert %{{Some, 123} => {0, {_, "c == b", "xxx", "3"}}} = state.conditions
      assert state.free == 1..99 |> Enum.to_list()
    end
  end

  describe "unregister" do
    test "basic" do
      assert {:ok, {BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(
                 @name,
                 Some,
                 123,
                 __ENV__,
                 "a == b",
                 nil,
                 "0"
               )

      BreakpointCondition.register_hit(@name, 0)

      assert :ok == BreakpointCondition.unregister_condition(@name, Some, 123)

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{}
      assert state.hits == %{}
      assert state.free == 0..99 |> Enum.to_list()
    end

    test "idempotency" do
      assert {:ok, {BreakpointCondition, :check_0}} ==
               BreakpointCondition.register_condition(
                 @name,
                 Some,
                 123,
                 __ENV__,
                 "a == b",
                 nil,
                 "1"
               )

      assert :ok == BreakpointCondition.unregister_condition(@name, Some, 123)
      assert :ok == BreakpointCondition.unregister_condition(@name, Some, 123)

      state = :sys.get_state(Process.whereis(@name))

      assert state.conditions == %{}
      assert state.free == 0..99 |> Enum.to_list()
    end
  end

  test "has_condition?" do
    assert {:ok, {BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, 123, __ENV__, "a == b", nil, "1")

    assert BreakpointCondition.has_condition?(@name, Some, 123)

    refute BreakpointCondition.has_condition?(@name, Some, 124)
    refute BreakpointCondition.has_condition?(@name, Other, 123)
  end

  test "get_condition" do
    assert {:ok, {BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, 123, __ENV__, "a == b", nil, "1")

    assert {:ok, {BreakpointCondition, :check_1}} ==
             BreakpointCondition.register_condition(
               @name,
               Some,
               124,
               __ENV__,
               "c == d",
               "xxx",
               "2"
             )

    BreakpointCondition.register_hit(@name, 1)

    assert {_, "a == b", nil, "1", 0} = BreakpointCondition.get_condition(@name, 0)
    assert {_, "c == d", "xxx", "2", 1} = BreakpointCondition.get_condition(@name, 1)
  end

  test "register_hit" do
    assert {:ok, {BreakpointCondition, :check_0}} ==
             BreakpointCondition.register_condition(@name, Some, 123, __ENV__, "a == b", nil, "1")

    BreakpointCondition.register_hit(@name, 0)
    assert :sys.get_state(Process.whereis(@name)).hits == %{0 => 1}
    BreakpointCondition.register_hit(@name, 0)
    assert :sys.get_state(Process.whereis(@name)).hits == %{0 => 2}
  end

  describe "evel_condition" do
    test "evals to true" do
      binding = [{:a, 1}, {:b, 1}]
      assert BreakpointCondition.eval_condition("a == b", binding, __ENV__) == true
    end

    test "evals to truthy" do
      binding = [{:a, 1}]
      assert BreakpointCondition.eval_condition("a", binding, __ENV__) == true
    end

    test "evals to false" do
      binding = [{:a, 1}, {:b, 2}]
      assert BreakpointCondition.eval_condition("a == b", binding, __ENV__) == false
    end

    test "evals to falsy" do
      binding = [{:a, nil}]
      assert BreakpointCondition.eval_condition("a", binding, __ENV__) == false
    end

    test "handles raise" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("raise ArgumentError", [], __ENV__) == false
      end)
    end

    test "handles throw" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("throw :asd", [], __ENV__) == false
      end)
    end

    test "handles exit" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_condition("exit(:normal)", [], __ENV__) == false
      end)
    end
  end

  describe "eval_hit_condition" do
    test "evals to number" do
      binding = [{:a, 1}]
      assert BreakpointCondition.eval_hit_condition("1 + 2.5", binding, __ENV__) == 3.5
    end

    test "defaults to 0" do
      binding = [{:a, 1}, {:b, 2}]
      assert BreakpointCondition.eval_hit_condition("false", binding, __ENV__) == 0
    end

    test "handles raise" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_hit_condition("raise ArgumentError", [], __ENV__) == 0
      end)
    end

    test "handles throw" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_hit_condition("throw :asd", [], __ENV__) == 0
      end)
    end

    test "handles exit" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.eval_hit_condition("exit(:normal)", [], __ENV__) == 0
      end)
    end
  end

  describe "interpolate" do
    test "basic" do
      assert BreakpointCondition.interpolate("", [], __ENV__) == ""
      assert BreakpointCondition.interpolate("abc", [], __ENV__) == "abc"
    end

    test "escape sequences" do
      assert BreakpointCondition.interpolate("\\{", [], __ENV__) == "{"
      assert BreakpointCondition.interpolate("\\}", [], __ENV__) == "}"
    end

    test "substitute variable" do
      assert BreakpointCondition.interpolate("abc{myvar}cde", [myvar: "123"], __ENV__) ==
               "abc123cde"

      assert BreakpointCondition.interpolate("abc{myvar}cde", [myvar: 123], __ENV__) ==
               "abc123cde"
    end

    test "escape sequence within substitution" do
      assert BreakpointCondition.interpolate("abc{inspect(%\\{\\})}cde", [], __ENV__) ==
               "abc%{}cde"
    end

    test "invalid" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.interpolate("abc{myvar{cde", [], __ENV__) == "abc"
        assert BreakpointCondition.interpolate("abc{myvarcde", [myvar: 123], __ENV__) == "abc"
      end)
    end

    test "error in substitution" do
      capture_io(:standard_error, fn ->
        assert BreakpointCondition.interpolate("abc{myvar}cde", [], __ENV__) == "abccde"

        assert BreakpointCondition.interpolate("abc{self()}cde", [myvar: 123], __ENV__) ==
                 "abccde"

        assert BreakpointCondition.interpolate("abc{throw :error}cde", [myvar: 123], __ENV__) ==
                 "abccde"
      end)
    end
  end
end
