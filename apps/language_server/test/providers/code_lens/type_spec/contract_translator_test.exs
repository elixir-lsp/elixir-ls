defmodule ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec.ContractTranslatorTest do
  use ExUnit.Case, async: true
  alias ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec.ContractTranslator

  test "translate struct when struct.t type exists" do
    contract = '() -> \#{\'__struct__\':=\'Elixir.DateTime\'}'
    assert "foo :: DateTime.t()" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "don't translate struct when struct.t type does not exist" do
    contract = '() -> \#{\'__struct__\':=\'Elixir.SomeOtherStruct\'}'

    assert "foo :: %SomeOtherStruct{}" ==
             ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "struct" do
    contract = '() -> \#{\'__struct__\':=atom(), atom()=>any()}'
    assert "foo :: struct" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "drop macro env argument" do
    contract = '(any(), integer()) -> integer()'

    assert "foo(any, integer) :: integer" ==
             ContractTranslator.translate_contract(:foo, contract, false)

    assert "foo(integer) :: integer" ==
             ContractTranslator.translate_contract(:foo, contract, true)
  end

  test "atom :ok" do
    contract = '(any()) -> ok'
    assert "foo(any) :: :ok" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "atom true" do
    contract = '(any()) -> true'
    assert "foo(any) :: true" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "atom _ substitution" do
    contract = '(_) -> false'
    assert "foo(any) :: false" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "do not drop when substitutions" do
    contract = '(X) -> atom() when X :: any()'

    assert "foo(x) :: atom when x: any" ==
             ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "keyword" do
    contract = '(any()) -> list({atom(), any()})'
    assert "foo(any) :: keyword" == ContractTranslator.translate_contract(:foo, contract, false)

    contract = '(any()) -> list({atom(), _})'
    assert "foo(any) :: keyword" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "keyword(t)" do
    contract = '(any()) -> list({atom(), integer()})'

    assert "foo(any) :: keyword(integer)" ==
             ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "[type]" do
    contract = '(any()) -> list(atom())'
    assert "foo(any) :: [atom]" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "list" do
    contract = '(any()) -> list(any())'
    assert "foo(any) :: list" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "empty list" do
    contract = '(any()) -> []'
    assert "foo(any) :: []" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "[...]" do
    contract = '(any()) -> nonempty_list(any())'
    assert "foo(any) :: [...]" == ContractTranslator.translate_contract(:foo, contract, false)

    contract = '(any()) -> nonempty_list(_)'
    assert "foo(any) :: [...]" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "[type, ...]" do
    contract = '(any()) -> nonempty_list(atom())'

    assert "foo(any) :: [atom, ...]" ==
             ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "undoes conversion of :_ to any inside bitstring" do
    contract = '(any()) -> <<_:2, _:_*3>>'

    assert "foo(any) :: <<_::2, _::_*3>>" ==
             ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "function" do
    contract = '(any()) -> fun((...) -> ok)'

    assert "foo(any) :: (... -> :ok)" ==
             ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "fun" do
    contract = '(any()) -> fun((...) -> any())'
    assert "foo(any) :: fun" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "empty map" do
    contract = '(any()) -> \#{}'
    assert "foo(any) :: %{}" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "map" do
    contract = '(any()) -> \#{any()=>any()}'
    assert "foo(any) :: map" == ContractTranslator.translate_contract(:foo, contract, false)
  end

  test "map with fields" do
    contract = '(any()) -> \#{integer()=>any(), 1:=atom(), abc:=4}'

    assert "foo(any) :: %{optional(integer) => any, 1 => atom, :abc => 4}" ==
             ContractTranslator.translate_contract(:foo, contract, false)
  end
end
