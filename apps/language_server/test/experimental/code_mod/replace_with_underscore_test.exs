defmodule ElixirLS.LanguageServer.Experimental.CodeMod.ReplaceWithUnderscoreTest do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.ReplaceWithUnderscore

  use ElixirLS.Test.CodeMod.Case

  def apply_code_mod(original_text, ast, options) do
    variable = Keyword.get(options, :variable, :unused)
    ReplaceWithUnderscore.apply(original_text, ast, variable)
  end

  describe "fixes in parameters" do
    test "applied to an unadorned param" do
      {:ok, result} =
        ~q[
          def my_func(unused) do
        ]
        |> modify()

      assert result == "def my_func(_unused) do"
    end

    test "applied to a pattern match in params" do
      {:ok, result} =
        ~q[
          def my_func(%SourceFile{} = unused) do
        ]
        |> modify()

      assert result == "def my_func(%SourceFile{} = _unused) do"
    end

    test "applied to a pattern match preceding a struct in params" do
      {:ok, result} =
        ~q[
          def my_func(unused = %SourceFile{}) do
        ]
        |> modify()

      assert result == "def my_func(_unused = %SourceFile{}) do"
    end

    test "applied prior to a map" do
      {:ok, result} =
        ~q[
          def my_func(unused = %{}) do
        ]
        |> modify()

      assert result == "def my_func(_unused = %{}) do"
    end

    test "applied after a map %{} = unused" do
      {:ok, result} =
        ~q[
          def my_func(%{} = unused) do
        ]
        |> modify()

      assert result == "def my_func(%{} = _unused) do"
    end

    test "applied to a map key %{foo: unused}" do
      {:ok, result} =
        ~q[
          def my_func(%{foo: unused}) do
        ]
        |> modify()

      assert result == "def my_func(%{foo: _unused}) do"
    end

    test "applied to a list element params = [unused, a, b | rest]" do
      {:ok, result} =
        ~q{
          def my_func([unused, a, b | rest]) do
        }
        |> modify()

      assert result == "def my_func([_unused, a, b | rest]) do"
    end

    test "applied to the tail of a list params = [a, b, | unused]" do
      {:ok, result} =
        ~q{
          def my_func([a, b | unused]) do
        }
        |> modify()

      assert result == "def my_func([a, b | _unused]) do"
    end
  end

  describe "fixes in variables" do
    test "applied to a variable match " do
      {:ok, result} =
        ~q[
          x = 3
        ]
        |> modify(variable: "x")

      assert result == "_x = 3"
    end

    test "applied to a variable match, preserves comments" do
      {:ok, result} =
        ~q[
          unused = bar # TODO: Fix this
        ]
        |> modify()

      assert result == "_unused = bar # TODO: Fix this"
    end

    test "preserves spacing" do
      {:ok, result} =
        "   x = 3"
        |> modify(variable: "x", trim: false)

      assert result == "   _x = 3"
    end

    test "applied to a variable with a pattern matched struct" do
      {:ok, result} =
        ~q[
          unused = %Struct{}
        ]
        |> modify()

      assert result == "_unused = %Struct{}"
    end

    test "applied to a variable with a pattern matched struct preserves trailing comments" do
      {:ok, result} =
        ~q[
          unused = %Struct{} # TODO: fix
        ]
        |> modify()

      assert result == "_unused = %Struct{} # TODO: fix"
    end

    test "applied to struct param matches" do
      {:ok, result} =
        ~q[
          %Struct{field: unused, other_field: used}
        ]
        |> modify()

      assert result == "%Struct{field: _unused, other_field: used}"
    end

    test "applied to a struct module match %module{}" do
      {:ok, result} =
        ~q[
          %unused{field: first, other_field: used}
        ]
        |> modify()

      assert result == "%_unused{field: first, other_field: used}"
    end

    test "applied to a tuple value" do
      {:ok, result} =
        ~q[
          {a, b, unused, c} = whatever
        ]
        |> modify()

      assert result == "{a, b, _unused, c} = whatever"
    end

    test "applied to a list element" do
      {:ok, result} =
        ~q{
          [a, b, unused, c] = whatever
        }
        |> modify()

      assert result == "[a, b, _unused, c] = whatever"
    end

    test "applied to map value" do
      {:ok, result} =
        ~q[
          %{foo: a, bar: unused} = whatever
        ]
        |> modify()

      assert result == "%{foo: a, bar: _unused} = whatever"
    end
  end

  describe "fixes in structures" do
    test "applied to a match of a comprehension" do
      {:ok, result} =
        ~q[
        for {unused, something_else} <- my_enum, do: something_else
        ]
        |> modify()

      assert result == "for {_unused, something_else} <- my_enum, do: something_else"
    end

    test "applied to a match in a with block" do
      {:ok, result} =
        ~q[
          with {unused, something_else} <- my_enum, do: something_else
        ]
        |> modify()

      assert result == "with {_unused, something_else} <- my_enum, do: something_else"
    end
  end
end
