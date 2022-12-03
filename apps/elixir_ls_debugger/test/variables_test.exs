defmodule ElixirLS.Debugger.VariablesTest do
  use ElixirLS.Utils.MixTest.Case, async: true
  alias ElixirLS.Debugger.Variables

  test "type" do
    assert Variables.type(1234) == "integer"

    assert Variables.type(123.4) == "float"

    assert Variables.type("") == "binary"
    assert Variables.type("asdc") == "binary"

    assert Variables.type(<<0::size(1)>>) == "bitstring"

    assert Variables.type({}) == "tuple"
    assert Variables.type({1}) == "tuple"
    assert Variables.type({:ok, 3}) == "tuple"

    assert Variables.type(true) == "boolean"
    assert Variables.type(false) == "boolean"

    assert Variables.type(nil) == "nil"

    assert Variables.type(:asd) == "atom"

    assert Variables.type(Elixir) == "atom"
    assert Variables.type(Some) == "module"
    assert Variables.type(Some.Module) == "module"

    assert Variables.type(:erlang.make_ref()) == "reference"

    assert Variables.type(fn -> :ok end) == "function"

    assert Variables.type(spawn(fn -> :ok end)) == "pid"

    assert Variables.type(hd(:erlang.ports())) == "port"

    assert Variables.type([]) == "list"
    assert Variables.type([1]) == "list"
    assert Variables.type('asd') == "list"

    assert Variables.type(abc: 123) == "keyword"

    assert Variables.type(%{}) == "map"
    assert Variables.type(%{asd: 123}) == "map"
    assert Variables.type(%{"asd" => 123}) == "map"

    assert Variables.type(%Date{year: 2022, month: 1, day: 1}) == "%Date{}"
    assert Variables.type(%ArgumentError{}) == "%ArgumentError{}"
  end

  test "num_children" do
    assert Variables.num_children(1234) == 0

    assert Variables.num_children(123.4) == 0

    assert Variables.num_children("") == 0
    assert Variables.num_children("asdc") == 4

    assert Variables.num_children(<<0::size(1)>>) == 1
    assert Variables.num_children(<<0::size(7)>>) == 1
    assert Variables.num_children(<<0::size(8)>>) == 1
    assert Variables.num_children(<<0::size(9)>>) == 2

    assert Variables.num_children({}) == 0
    assert Variables.num_children({1}) == 1
    assert Variables.num_children({:ok, 3}) == 2

    assert Variables.num_children(true) == 0
    assert Variables.num_children(false) == 0

    assert Variables.num_children(nil) == 0

    assert Variables.num_children(:asd) == 0

    assert Variables.num_children(Elixir) == 0
    assert Variables.num_children(Some) == 0
    assert Variables.num_children(Some.Module) == 0

    assert Variables.num_children(:erlang.make_ref()) == 0

    # As of OTP 24 10 values but it's better not to hardcode that
    assert Variables.num_children(fn -> :ok end) != 0

    # As of OTP 24 16 values but it's better not to hardcode that
    assert Variables.num_children(self()) != 0

    # As of OTP 24 7 values but it's better not to hardcode that
    assert Variables.num_children(hd(:erlang.ports())) != 0

    assert Variables.num_children([]) == 0
    assert Variables.num_children([1]) == 1
    assert Variables.num_children('asd') == 3

    assert Variables.num_children(abc: 123) == 1

    assert Variables.num_children(%{}) == 0
    assert Variables.num_children(%{asd: 123}) == 1
    assert Variables.num_children(%{"asd" => 123}) == 1

    assert Variables.num_children(%Date{year: 2022, month: 1, day: 1}) == 5
    assert Variables.num_children(%ArgumentError{}) == 3
  end

  describe "children" do
    test "list" do
      assert Variables.children([], 0, 10) == []
      assert Variables.children([1], 0, 10) == [{"0", 1}]
      assert Variables.children([1, 2, 3, 4], 0, 2) == [{"0", 1}, {"1", 2}]
      assert Variables.children([1, 2, 3, 4], 1, 2) == [{"1", 2}, {"2", 3}]
      assert Variables.children('asd', 0, 10) == [{"0", 97}, {"1", 115}, {"2", 100}]
    end

    test "keyword" do
      assert Variables.children([abc: 123], 0, 10) == [abc: 123]

      assert Variables.children([abc1: 121, abc2: 122, abc3: 123, abc4: 124], 0, 2) == [
               abc1: 121,
               abc2: 122
             ]

      assert Variables.children([abc1: 121, abc2: 122, abc3: 123, abc4: 124], 1, 2) == [
               abc2: 122,
               abc3: 123
             ]
    end

    test "tuple" do
      assert Variables.children({}, 0, 10) == []
      assert Variables.children({1}, 0, 10) == [{"0", 1}]
      assert Variables.children({:ok, 3}, 0, 10) == [{"0", :ok}, {"1", 3}]
      assert Variables.children({:ok, 3}, 1, 10) == [{"1", 3}]
    end

    test "map" do
      assert Variables.children(%{}, 0, 10) == []
      assert Variables.children(%{asd: 123}, 0, 10) == [{"asd", 123}]
      assert Variables.children(%{Date: 123}, 0, 10) == [{"Date", 123}]
      assert Variables.children(%{"asd" => 123}, 0, 10) == [{"\"asd\"", 123}]

      assert Variables.children(%Date{year: 2022, month: 1, day: 1}, 0, 10) == [
               {"__struct__", Date},
               {"calendar", Calendar.ISO},
               {"day", 1},
               {"month", 1},
               {"year", 2022}
             ]

      assert Variables.children(%ArgumentError{}, 0, 10) == [
               {"__exception__", true},
               {"__struct__", ArgumentError},
               {"message", "argument error"}
             ]

      assert Variables.children(%ArgumentError{}, 1, 10) == [
               {"__struct__", ArgumentError},
               {"message", "argument error"}
             ]

      assert Variables.children(%ArgumentError{}, 1, 1) == [{"__struct__", ArgumentError}]
    end

    test "binary" do
      assert Variables.children("", 0, 10) == []
      assert Variables.children("asdc", 0, 10) == [{"0", 97}, {"1", 115}, {"2", 100}, {"3", 99}]
      assert Variables.children("asdc", 1, 10) == [{"1", 115}, {"2", 100}, {"3", 99}]
      assert Variables.children("asdc", 1, 2) == [{"1", 115}, {"2", 100}]
    end

    test "bitstring" do
      assert Variables.children(<<0::size(1)>>, 0, 10) == [{"0", <<0::size(1)>>}]
      assert Variables.children(<<0::size(3)>>, 0, 10) == [{"0", <<0::size(3)>>}]
      assert Variables.children(<<0::size(8)>>, 0, 10) == [{"0", 0}]
      assert Variables.children(<<0::size(9)>>, 0, 10) == [{"0", 0}, {"1", <<0::size(1)>>}]

      assert Variables.children(<<0::size(17)>>, 1, 10) == [{"1", 0}, {"2", <<0::size(1)>>}]
      assert Variables.children(<<0::size(17)>>, 1, 1) == [{"1", 0}]
    end

    test "fun" do
      children = Variables.children(fn -> :ok end, 0, 10)
      assert children[:module] == ElixirLS.Debugger.VariablesTest
      assert children[:type] == :local
      assert children[:arity] == 0
    end

    test "pid" do
      children = Variables.children(self(), 0, 10)
      assert children[:trap_exit] == false
      assert children[:status] == :running
    end

    test "port" do
      children = Variables.children(hd(:erlang.ports()), 0, 10)

      case :os.type() do
        {:win32, _} ->
          assert children[:name] == '2/2'

        _ ->
          assert children[:name] == 'forker'
      end
    end
  end
end
