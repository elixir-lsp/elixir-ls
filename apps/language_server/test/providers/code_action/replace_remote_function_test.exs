defmodule ElixirLS.LanguageServer.Providers.CodeAction.ReplaceRemoteFunctionTest do
  use ElixirLS.LanguageServer.Test.CodeMod.Case

  alias ElixirLS.LanguageServer.Providers.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.SourceFile

  import ElixirLS.LanguageServer.Protocol

  @default_message """
  Enum.counts/1 is undefined or private. Did you mean:

        * concat/1
        * concat/2
        * count/1
        * count/2
  """

  @foo_message """
  ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:

  * foo/1
  """

  def apply_code_mod(original_text, options) do
    line_number = Keyword.get(options, :line, 0)

    source_file = %SourceFile{text: original_text, version: 0}
    uri = "file:///file.ex"

    message = Keyword.get(options, :message, @default_message)
    range = range(line_number, 0, line_number + 1, 0)

    diagnostics = [
      %{
        "message" => message,
        "range" => range
      }
    ]

    changes =
      source_file
      |> ReplaceRemoteFunction.apply(uri, diagnostics)
      |> Enum.map(& &1.edit.changes[uri])

    {:ok, changes}
  end

  def filter_edited_texts(edited_texts, options) do
    suggestion = Keyword.get(options, :suggestion, "Enum.count")

    filtered_texts = Enum.filter(edited_texts, &String.contains?(&1, suggestion))

    {:ok, filtered_texts}
  end

  describe "fixes function call" do
    test "applied to a standalone call" do
      {:ok, [result]} =
        ~q{
          Enum.counts([1, 2, 3])
        }t
        |> modify()

      assert result == "Enum.count([1, 2, 3])"
    end

    test "applied to a variable match" do
      {:ok, [result]} =
        ~q{
          x = Enum.counts([1, 2, 3])
        }t
        |> modify()

      assert result == "x = Enum.count([1, 2, 3])"
    end

    test "not changing variable name" do
      {:ok, [result]} =
        ~q{
          counts = Enum.counts([1, 2, 3])
        }t
        |> modify()

      assert result == "counts = Enum.count([1, 2, 3])"
    end

    test "applied to a call after a pipe" do
      {:ok, [result]} =
        ~q{
          [1, 2, 3] |> Enum.counts()
        }t
        |> modify()

      assert result == "[1, 2, 3] |> Enum.count()"
    end

    test "changing only a function from provided possible modules" do
      {:ok, [result]} =
        ~q{
          Enumerable.counts([1, 2, 3]) + Enum.counts([3, 2, 1])
        }t
        |> modify()

      assert result == "Enumerable.counts([1, 2, 3]) + Enum.count([3, 2, 1])"
    end

    test "changing all occurrences of the function in the line" do
      {:ok, [result]} =
        ~q{
          Enum.counts([1, 2, 3]) + Enum.counts([3, 2, 1])
        }t
        |> modify()

      assert result == "Enum.count([1, 2, 3]) + Enum.count([3, 2, 1])"
    end

    test "applied in a comprehension" do
      {:ok, [result]} =
        ~q{
          for x <- Enum.counts([[1], [2], [3]]), do: Enum.counts([[1], [2], [3], [x]])
        }t
        |> modify(suggestion: "Enum.concat")

      assert result ==
               "for x <- Enum.concat([[1], [2], [3]]), do: Enum.concat([[1], [2], [3], [x]])"
    end

    test "applied in a with block" do
      {:ok, [result]} =
        ~q{
          with x <- Enum.counts([1, 2, 3]), do: x
        }t
        |> modify()

      assert result == "with x <- Enum.count([1, 2, 3]), do: x"
    end

    test "applied in a do-end with block preserves indent" do
      {:ok, [result]} =
        ~q{
          with x <- Enum.counts([1, 2, 3]) do
            nil
          end
        }t
        |> modify()

      assert result == "with x <- Enum.count([1, 2, 3]) do\n  nil\nend"
    end

    test "applied to a branch in a case" do
      {:ok, [result]} =
        ~q{
          case my_thing do
            :ok -> Enum.counts([1, 2, 3])
            _ -> :error
          end
        }t
        |> modify(line: 1)

      expected =
        ~q{
          case my_thing do
            :ok -> Enum.count([1, 2, 3])
            _ -> :error
          end
        }t

      assert result == expected
    end

    test "no change when unformatted line" do
      {:ok, result} =
        ~q{
          case my_thing do
            :ok  -> Enum.counts([1,  2,  3])
            _ -> :error
          end
        }t
        |> modify(line: 1)

      assert result == []
    end

    test "applied to an erlang function" do
      message = """
      :ets.inserd/2 is undefined or private. Did you mean:
            * insert/2
            * insert_new/2
      """

      {:ok, [result]} =
        ~q{
          :ets.inserd(a, b)
        }t
        |> modify(message: message, suggestion: ":ets.insert(a, b)")

      assert result == ":ets.insert(a, b)"
    end

    test "when aliased" do
      {:ok, [result]} =
        ~q{
          alias ElixirLS.Test.RemoteFunction
          RemoteFunction.fou(42)
        }t
        |> modify(message: @foo_message, suggestion: "RemoteFunction.foo", line: 1)

      assert result == "alias ElixirLS.Test.RemoteFunction\nRemoteFunction.foo(42)"
    end

    test "when aliased with a custom name" do
      {:ok, [result]} =
        ~q{
          alias ElixirLS.Test.RemoteFunction, as: Remote
          Remote.fou(42)
        }t
        |> modify(message: @foo_message, suggestion: "Remote.foo", line: 1)

      assert result == "alias ElixirLS.Test.RemoteFunction, as: Remote\nRemote.foo(42)"
    end

    test "preserves other lines" do
      {:ok, [result]} =
        ~q{
          # 1st comment


          Enum.counts([1, 2, 3]) # 2nd comment
          # 3rd comment

          Enum.counts([1, 2, 3])
        }t
        |> modify(line: 6, suggestion: "Enum.concat")

      expected =
        ~q{
          # 1st comment


          Enum.counts([1, 2, 3]) # 2nd comment
          # 3rd comment

          Enum.concat([1, 2, 3])
        }t

      assert result == expected
    end
  end

  describe "fixes captured function" do
    test "applied to a standalone function" do
      {:ok, [result]} =
        ~q[
          &Enum.counts/1
        ]t
        |> modify()

      assert result == "&Enum.count/1"
    end

    test "applied to a variable match" do
      {:ok, [result]} =
        ~q[
          x = &Enum.counts/1
        ]t
        |> modify()

      assert result == "x = &Enum.count/1"
    end

    test "not changing variable name" do
      {:ok, [result]} =
        ~q[
          counts = &Enum.counts/1
        ]t
        |> modify()

      assert result == "counts = &Enum.count/1"
    end

    test "applied to an argument" do
      {:ok, [result]} =
        ~q{
          [[1, 2], [3, 4]] |> Enum.map(&Enum.counts/1)
        }t
        |> modify()

      assert result == "[[1, 2], [3, 4]] |> Enum.map(&Enum.count/1)"
    end

    test "changing only a function from provided possible modules" do
      {:ok, [result]} =
        ~q{
          [&Enumerable.counts/1, &Enum.counts/1]
        }t
        |> modify()

      assert result == "[&Enumerable.counts/1, &Enum.count/1]"
    end

    test "changing all occurrences of the function in the line" do
      {:ok, [result]} =
        ~q{
          [&Enum.counts/1, &Enum.counts/1]
        }t
        |> modify()

      assert result == "[&Enum.count/1, &Enum.count/1]"
    end

    test "applied to a branch in a case" do
      {:ok, [result]} =
        ~q[
        case my_thing do
          :ok -> &Enum.counts/1
          _ -> :error
        end
      ]t
        |> modify(line: 1)

      expected =
        ~q[
        case my_thing do
          :ok -> &Enum.count/1
          _ -> :error
        end
      ]t

      assert result == expected
    end

    test "no change when unformatted line" do
      {:ok, result} =
        ~q{
          case my_thing do
            :ok -> & Enum.counts/1
            _ -> :error
          end
        }t
        |> modify(line: 1)

      assert result == []
    end

    test "applied to an erlang function" do
      message = """
      :ets.inserd/2 is undefined or private. Did you mean:
            * insert/2
            * insert_new/2
      """

      {:ok, [result]} =
        ~q{
          &:ets.inserd/2
        }t
        |> modify(message: message, suggestion: ":ets.insert/2")

      assert result == "&:ets.insert/2"
    end

    test "when aliased" do
      {:ok, [result]} =
        ~q{
          alias ElixirLS.Test.RemoteFunction
          &RemoteFunction.fou/1
        }t
        |> modify(message: @foo_message, suggestion: "RemoteFunction.foo", line: 1)

      assert result == "alias ElixirLS.Test.RemoteFunction\n&RemoteFunction.foo/1"
    end

    test "when aliased with a custom name" do
      {:ok, [result]} =
        ~q{
          alias ElixirLS.Test.RemoteFunction, as: Remote
          &Remote.fou/1
        }t
        |> modify(message: @foo_message, suggestion: "Remote.foo", line: 1)

      assert result == "alias ElixirLS.Test.RemoteFunction, as: Remote\n&Remote.foo/1"
    end

    test "preserves other lines" do
      {:ok, [result]} =
        ~q{
          # 1st comment


          x = &Enum.counts/1 # 2nd comment
          # 3rd comment

          &Enum.counts/1
        }t
        |> modify(line: 6, suggestion: "Enum.concat")

      expected =
        ~q{
          # 1st comment


          x = &Enum.counts/1 # 2nd comment
          # 3rd comment

          &Enum.concat/1
        }t

      assert result == expected
    end
  end
end
