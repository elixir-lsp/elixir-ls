defmodule ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec.ContractTranslatorTest do
  use ExUnit.Case, async: true
  alias ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec.ContractTranslator

  test "translate struct when struct.t type exists" do
    contract = ~c"() -> \#{'__struct__':='Elixir.DateTime'}"

    assert "foo() :: DateTime.t()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "don't translate struct when struct.t type does not exist" do
    contract = ~c"() -> \#{'__struct__':='Elixir.SomeOtherStruct'}"

    assert "foo() :: %SomeOtherStruct{}" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "struct" do
    contract = ~c"() -> \#{'__struct__':=atom(), atom()=>any()}"

    assert "foo() :: struct()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "drop macro env argument" do
    contract = ~c"(any(), integer()) -> integer()"

    assert "foo(any(), integer()) :: integer()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)

    assert "foo(integer()) :: integer()" ==
             ContractTranslator.translate_contract(:foo, contract, true, Atom)
  end

  test "atom :ok" do
    contract = ~c"(any()) -> ok"

    assert "foo(any()) :: :ok" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "atom true" do
    contract = ~c"(any()) -> true"

    assert "foo(any()) :: true" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "atom _ substitution" do
    contract = ~c"(_) -> false"

    assert "foo(any()) :: false" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "do not drop when substitutions" do
    contract = ~c"(X) -> atom() when X :: any()"

    assert "foo(x) :: atom() when x: any()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "keyword" do
    contract = ~c"(any()) -> list({atom(), any()})"

    assert "foo(any()) :: keyword()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)

    contract = ~c"(any()) -> list({atom(), _})"

    assert "foo(any()) :: keyword()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "keyword(t)" do
    contract = ~c"(any()) -> list({atom(), integer()})"

    assert "foo(any()) :: keyword(integer())" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "[type]" do
    contract = ~c"(any()) -> list(atom())"

    assert "foo(any()) :: [atom()]" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "list" do
    contract = ~c"(any()) -> list(any())"

    assert "foo(any()) :: list()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "empty list" do
    contract = ~c"(any()) -> []"

    assert "foo(any()) :: []" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "[...]" do
    contract = ~c"(any()) -> nonempty_list(any())"

    assert "foo(any()) :: [...]" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)

    contract = ~c"(any()) -> nonempty_list(_)"

    assert "foo(any()) :: [...]" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "[type, ...]" do
    contract = ~c"(any()) -> nonempty_list(atom())"

    assert "foo(any()) :: [atom(), ...]" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "undoes conversion of :_ to any inside bitstring" do
    contract = ~c"(any()) -> <<_:2, _:_*3>>"

    assert "foo(any()) :: <<_::2, _::_*3>>" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "function" do
    contract = ~c"(any()) -> fun((...) -> ok)"

    assert "foo(any()) :: (... -> :ok)" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "fun" do
    contract = ~c"(any()) -> fun((...) -> any())"

    assert "foo(any()) :: fun()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "empty map" do
    contract = ~c"(any()) -> \#{}"

    assert "foo(any()) :: %{}" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "map" do
    contract = ~c"(any()) -> \#{any()=>any()}"

    assert "foo(any()) :: map()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "map with fields" do
    contract = ~c"(any()) -> \#{integer()=>any(), 1:=atom(), abc:=4}"

    expected = "foo(any()) :: %{optional(integer()) => any(), 1 => atom(), abc: 4}"

    assert expected ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "defprotocol type t" do
    contract = ~c"(any()) -> any()"

    assert "foo(t()) :: any()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Enumerable)

    contract = ~c"(any(), any()) -> any()"

    assert "foo(t(), any()) :: any()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Enumerable)

    contract = ~c"(any()) -> any()"

    assert "foo(any()) :: any()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)

    contract = ~c"(any(), any()) -> any()"

    assert "foo(any(), any()) :: any()" ==
             ContractTranslator.translate_contract(:foo, contract, false, Atom)
  end

  test "defimpl first arg" do
    contract = ~c"(any()) -> any()"

    assert "count(list()) :: any()" ==
             ContractTranslator.translate_contract(:count, contract, false, Enumerable.List)

    contract = ~c"(any()) -> any()"

    assert "count(Date.Range.t()) :: any()" ==
             ContractTranslator.translate_contract(:count, contract, false, Enumerable.Date.Range)
  end
end
