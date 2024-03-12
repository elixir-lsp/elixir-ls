defmodule ElixirLS.LanguageServer.Providers.CodeAction.ReplaceWithUnderscoreTest do
  use ElixirLS.LanguageServer.Test.CodeMod.Case

  alias ElixirLS.LanguageServer.Providers.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.SourceFile

  import ElixirLS.LanguageServer.Protocol

  def apply_code_mod(original_text, options) do
    variable = Keyword.get(options, :variable, :unused)
    line_number = Keyword.get(options, :line, 0)

    source_file = %SourceFile{text: original_text, version: 0}
    uri = "file:///file.ex"

    message =
      """
      variable "#{variable}" is unused (if the variable is not meant to be used, prefix it with an underscore)
      """
      |> String.trim()

    range = range(line_number, 0, line_number + 1, 0)

    diagnostics = [
      %{
        "message" => message,
        "range" => range
      }
    ]

    changes =
      source_file
      |> ReplaceWithUnderscore.apply(uri, diagnostics)
      |> Enum.map(& &1.edit.changes[uri])

    {:ok, changes}
  end

  describe "fixes in parameters" do
    test "applied to an unadorned param" do
      {:ok, [result]} =
        ~q[
          def my_func(unused), do: nil
        ]t
        |> modify()

      assert result == "def my_func(_unused), do: nil"
    end

    test "applied to a pattern match in params" do
      {:ok, [result]} =
        ~q[
          def my_func(%SourceFile{} = unused), do: nil
        ]t
        |> modify()

      assert result == "def my_func(%SourceFile{} = _unused), do: nil"
    end

    test "applied to a pattern match preceding a struct in params" do
      {:ok, [result]} =
        ~q[
          def my_func(unused = %SourceFile{}), do: nil
        ]t
        |> modify()

      assert result == "def my_func(_unused = %SourceFile{}), do: nil"
    end

    test "applied prior to a map" do
      {:ok, [result]} =
        ~q[
          def my_func(unused = %{}), do: nil
        ]t
        |> modify()

      assert result == "def my_func(_unused = %{}), do: nil"
    end

    test "applied after a map %{} = unused" do
      {:ok, [result]} =
        ~q[
          def my_func(%{} = unused), do: nil
        ]t
        |> modify()

      assert result == "def my_func(%{} = _unused), do: nil"
    end

    test "applied to a map key %{foo: unused}" do
      {:ok, [result]} =
        ~q[
          def my_func(%{foo: unused}), do: nil
        ]t
        |> modify()

      assert result == "def my_func(%{foo: _unused}), do: nil"
    end

    test "applied to a list element params = [unused, a, b | rest]" do
      {:ok, [result]} =
        ~q{
          def my_func([unused, a, b | rest]), do: nil
        }t
        |> modify()

      assert result == "def my_func([_unused, a, b | rest]), do: nil"
    end

    test "applied to the tail of a list params = [a, b, | unused]" do
      {:ok, [result]} =
        ~q{
          def my_func([a, b | unused]), do: nil
        }t
        |> modify()

      assert result == "def my_func([a, b | _unused]), do: nil"
    end

    test "does not change the name of a function if it is the same as a parameter" do
      {:ok, [result]} =
        ~q{
        def unused(unused) do
        end
      }t
        |> modify()

      assert result == "def unused(_unused) do\nend"
    end

    test "no change when unformatted line" do
      {:ok, result} =
        ~q[
          def  my_func(:a,  unused), do:   :ok
        ]t
        |> modify()

      assert result == []
    end
  end

  describe "fixes in variables" do
    test "applied to a variable match " do
      {:ok, [result]} =
        ~q[
          x = 3
        ]t
        |> modify(variable: "x")

      assert result == "_x = 3"
    end

    test "preserves indentation" do
      {:ok, [result]} =
        ~q[
          if true do
            x = 3
          end
        ]t
        |> modify(variable: "x", line: 1)

      assert result == "if true do\n  _x = 3\nend"
    end

    test "applied to a variable with a pattern matched struct" do
      {:ok, [result]} =
        ~q[
          unused = %Struct{}
        ]t
        |> modify()

      assert result == "_unused = %Struct{}"
    end

    test "applied to struct param matches" do
      {:ok, [result]} =
        ~q[
          %Struct{field: unused, other_field: used}
        ]t
        |> modify()

      assert result == "%Struct{field: _unused, other_field: used}"
    end

    test "applied to a struct module match %module{}" do
      {:ok, [result]} =
        ~q[
          %unused{field: first, other_field: used}
        ]t
        |> modify()

      assert result == "%_unused{field: first, other_field: used}"
    end

    test "applied to a tuple value" do
      {:ok, [result]} =
        ~q[
          {a, b, unused, c} = whatever
        ]t
        |> modify()

      assert result == "{a, b, _unused, c} = whatever"
    end

    test "applied to a list element" do
      {:ok, [result]} =
        ~q{
          [a, b, unused, c] = whatever
        }t
        |> modify()

      assert result == "[a, b, _unused, c] = whatever"
    end

    test "applied to map value" do
      {:ok, [result]} =
        ~q[
          %{foo: a, bar: unused} = whatever
        ]t
        |> modify()

      assert result == "%{foo: a, bar: _unused} = whatever"
    end

    test "preserves other lines" do
      {:ok, [result]} =
        ~q[
          # 1st comment


          x =  3 # 2nd comment
          # 3rd comment

          {foo, unused, bar}
        ]t
        |> modify(line: 6)

      expected =
        ~q[
          # 1st comment


          x =  3 # 2nd comment
          # 3rd comment

          {foo, _unused, bar}
        ]t

      assert result == expected
    end

    test "no change when unformatted multiline map" do
      {:ok, result} =
        ~q[
          %{
            foo: a,
            bar: unused} = whatever
        ]t
        |> modify(line: 2)

      assert result == []
    end
  end

  describe "fixes in structures" do
    test "applied to a match of a comprehension" do
      {:ok, [result]} =
        ~q[
          for {unused, something_else} <- my_enum, do: something_else
        ]t
        |> modify()

      assert result == "for {_unused, something_else} <- my_enum, do: something_else"
    end

    test "applied to a match in a with block" do
      {:ok, [result]} =
        ~q[
          with {unused, something_else} <- my_enum, do: something_else
        ]t
        |> modify()

      assert result == "with {_unused, something_else} <- my_enum, do: something_else"
    end

    test "applied to a branch in a case" do
      {:ok, [result]} =
        ~q[
          case my_thing do
            {:ok, unused} -> :ok
            _ -> :error
          end
        ]t
        |> modify(line: 1)

      expected =
        ~q[
          case my_thing do
            {:ok, _unused} -> :ok
            _ -> :error
          end
        ]t

      assert result == expected
    end
  end
end
