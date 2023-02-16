defmodule ElixirLS.Experimental.FormatTest do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Format
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  use ElixirLS.Test.CodeMod.Case

  def apply_code_mod(text, _ast, opts) do
    file_path = Keyword.get_lazy(opts, :file_path, &File.cwd!/0)

    text
    |> source_file()
    |> Format.text_edits(file_path)
  end

  def source_file(text) do
    SourceFile.new("file://#{__ENV__.file}", text, 1)
  end

  def unformatted do
    ~q[
    defmodule Unformatted do
      def something(  a,     b  ) do
    end
    end
    ]t
  end

  def formatted do
    ~q[
    defmodule Unformatted do
      def something(a, b) do
      end
    end
    ]t
  end

  describe "format/2" do
    test "it should be able to format a file in the project" do
      {:ok, result} = modify(unformatted())

      assert result == formatted()
    end

    test "it should be able to format a file when the project isn't specified" do
      assert {:ok, result} = modify(unformatted(), file_path: nil)
      assert result == formatted()
    end

    test "it should provide an error for a syntax error" do
      assert {:error, %SyntaxError{}} = ~q[
      def foo(a, ) do
        true
      end
      ] |> modify()
    end

    test "it should provide an error for a missing token" do
      assert {:error, %TokenMissingError{}} = ~q[
      defmodule TokenMissing do
       :bad
      ] |> modify()
    end

    test "it correctly handles unicode" do
      assert {:ok, result} = ~q[
        {"🎸",    "o"}
      ] |> modify()

      assert ~q[
        {"🎸", "o"}
      ]t == result
    end

    test "it can handles long lines" do
      unformatted = ~q[
        defmodule Unformatted do
          def foo1(s) do
            s = very_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooonooooong(s) |> IO.inputs()
            s
          end

          def very_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooonooooong(s) do
            s
          end
        end
      ]t

      formatted = ~q[
        defmodule Unformatted do
          def foo1(s) do
            s =
              very_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooonooooong(s) |> IO.inputs()

            s
          end

          def very_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooonooooong(s) do
            s
          end
        end
      ]t

      assert {:ok, formatted} == modify(unformatted)
    end

    test "it can handles the case of long line split into multiple lines" do
      unformatted = ~q[
        defmodule Unformatted do
          def foo(foo1, foo2, foo3, foo4, foo5, foo6, foo7, foo8, foo9, foo10, foo11, foo12, foo13, foo14, foo15, foo16) do
            foo = foo14 <> foo15 <> foo16
            {foo1, foo2, foo3, foo4, foo5, foo6, foo7, foo8, foo9, foo10, foo11, foo12, foo13, foo}
          end
        end
      ]t
      formatted = ~q[
        defmodule Unformatted do
          def foo(
                foo1,
                foo2,
                foo3,
                foo4,
                foo5,
                foo6,
                foo7,
                foo8,
                foo9,
                foo10,
                foo11,
                foo12,
                foo13,
                foo14,
                foo15,
                foo16
              ) do
            foo = foo14 <> foo15 <> foo16
            {foo1, foo2, foo3, foo4, foo5, foo6, foo7, foo8, foo9, foo10, foo11, foo12, foo13, foo}
          end
        end
      ]t

      assert {:ok, formatted} == modify(unformatted)
    end

    test "it handles extra lines" do
      assert {:ok, result} = ~q[
        defmodule  Unformatted do
          def something(    a        ,   b) do



          end
      end
      ] |> modify()

      assert result == formatted()
    end
  end
end
