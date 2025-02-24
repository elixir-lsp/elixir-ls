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
      }
        |> modify()

      assert result == "Enum.count([1, 2, 3])"
    end

    test "applied to a variable match" do
      {:ok, [result]} =
        ~q{
        x = Enum.counts([1, 2, 3])
      }
        |> modify()

      assert result == "x = Enum.count([1, 2, 3])"
    end

    test "applied to a variable match, preserves comments" do
      {:ok, [result]} =
        ~q{
        x = Enum.counts([1, 2, 3]) # TODO: Fix this
      }
        |> modify()

      assert result == "x = Enum.count([1, 2, 3]) # TODO: Fix this"
    end

    test "not changing variable name" do
      {:ok, [result]} =
        ~q{
        counts = Enum.counts([1, 2, 3])
      }
        |> modify()

      assert result == "counts = Enum.count([1, 2, 3])"
    end

    test "applied to a call after a pipe" do
      {:ok, [result]} =
        ~q{
        [1, 2, 3] |> Enum.counts()
      }
        |> modify()

      assert result == "[1, 2, 3] |> Enum.count()"
    end

    test "changing only a function from provided possible modules" do
      {:ok, [result]} =
        ~q{
        Enumerable.counts([1, 2, 3]) + Enum.counts([3, 2, 1])
      }
        |> modify()

      assert result == "Enumerable.counts([1, 2, 3]) + Enum.count([3, 2, 1])"
    end

    test "changing all occurrences of the function in the line" do
      {:ok, [result]} =
        ~q{
        Enum.counts([1, 2, 3]) + Enum.counts([3, 2, 1])
      }
        |> modify()

      assert result == "Enum.count([1, 2, 3]) + Enum.count([3, 2, 1])"
    end

    test "applied in a comprehension" do
      {:ok, [result]} =
        ~q{
        for x <- Enum.counts([[1], [2], [3]]), do: Enum.counts([[1], [2], [3], [x]])
      }
        |> modify(suggestion: "Enum.concat")

      assert result ==
               "for x <- Enum.concat([[1], [2], [3]]), do: Enum.concat([[1], [2], [3], [x]])"
    end

    test "applied in a with block" do
      {:ok, [result]} =
        ~q{
        with x <- Enum.counts([1, 2, 3]), do: x
      }
        |> modify()

      assert result == "with x <- Enum.count([1, 2, 3]), do: x"
    end

    test "applied in a with block, preserves comment" do
      {:ok, [result]} =
        ~q{
        with x <- Enum.counts([1, 2, 3]), do: x # TODO: Fix this
      }
        |> modify()

      assert result == "with x <- Enum.count([1, 2, 3]), do: x # TODO: Fix this"
    end

    test "applied in a with block with started do end" do
      {:ok, [result]} =
        ~q{
        with x <- Enum.counts([1, 2, 3]) do
      }
        |> modify()

      assert result == "with x <- Enum.count([1, 2, 3]) do"
    end

    test "preserving the leading indent" do
      {:ok, [result]} = modify("     Enum.counts([1, 2, 3])", trim: false)

      assert result == "     Enum.count([1, 2, 3])"
    end

    if System.otp_release() |> String.to_integer() >= 23 do
      test "handles erlang functions" do
        message = """
        :ets.inserd/2 is undefined or private. Did you mean:
              * insert/2
              * insert_new/2
        """

        {:ok, [result]} =
          ~q{
          :ets.inserd(a, b)
        }
          |> modify(message: message, suggestion: ":ets.insert(a, b)")

        assert result == ":ets.insert(a, b)"
      end

      if Version.match?(System.version(), ">= 1.15.0") do
        test "handles erlang functions aliased" do
          message = """
          :ets.inserd/2 is undefined or private. Did you mean:
                * insert/2
                * insert_new/2
          """

          {:ok, [result]} =
            ~q{
          alias :ets, as: Foo
          Foo.inserd(a, b)
        }
            |> modify(message: message, suggestion: "Foo.insert(a, b)", line: 1)

          assert result == "alias :ets, as: Foo\nFoo.insert(a, b)"
        end
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "when aliased" do
        message = """
        ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:

              * foo/1
        """

        {:ok, [result]} =
          ~q{
        alias ElixirLS.Test.RemoteFunction
        RemoteFunction.fou(42)
      }
          |> modify(message: message, suggestion: "RemoteFunction.foo", line: 1)

        assert result == "alias ElixirLS.Test.RemoteFunction\nRemoteFunction.foo(42)"
      end

      test "when erlang module aliased" do
        message = """
        ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:

              * foo/1
        """

        {:ok, [result]} =
          ~q{
        alias :ets, as: Foo
        alias ElixirLS.Test.RemoteFunction
        RemoteFunction.fou(42)
      }
          |> modify(message: message, suggestion: "RemoteFunction.foo", line: 2)

        assert result ==
                 "alias :ets, as: Foo\nalias ElixirLS.Test.RemoteFunction\nRemoteFunction.foo(42)"
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "when aliased with a custom name" do
        message = """
        ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:

              * foo/1
        """

        {:ok, [result]} =
          ~q{
        alias ElixirLS.Test.RemoteFunction, as: Remote
        Remote.fou(42)
      }
          |> modify(message: message, suggestion: "Remote.foo", line: 1)

        assert result == "alias ElixirLS.Test.RemoteFunction, as: Remote\nRemote.foo(42)"
      end

      test "handles __MODULE__" do
        message = """
        ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:
              * foo/1
        """

        {:ok, [result]} =
          ~q{
          __MODULE__.fou(42)
          }
          |> modify(message: message, suggestion: "__MODULE__.foo", line: 0)

        assert result == "__MODULE__.foo(42)"
      end

      test "handles __MODULE__.Submodule alias" do
        message = """
        ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:
              * foo/1
        """

        {:ok, [result]} =
          ~q{
          __MODULE__.RemoteFunction.fou(42)
          }
          |> modify(message: message, suggestion: "__MODULE__.RemoteFunction.foo", line: 0)

        assert result == "__MODULE__.RemoteFunction.foo(42)"
      end
    end
  end

  describe "fixes captured function" do
    test "applied to a standalone function" do
      {:ok, [result]} =
        ~q[
        &Enum.counts/1
      ]
        |> modify()

      assert result == "&Enum.count/1"
    end

    test "applied to a variable match" do
      {:ok, [result]} =
        ~q[
        x = &Enum.counts/1
      ]
        |> modify()

      assert result == "x = &Enum.count/1"
    end

    test "applied to a variable match, preserves comments" do
      {:ok, [result]} =
        ~q[
        x = &Enum.counts/1 # TODO: Fix this
      ]
        |> modify()

      assert result == "x = &Enum.count/1 # TODO: Fix this"
    end

    test "not changing variable name" do
      {:ok, [result]} =
        ~q{
        counts = &Enum.counts/1
      }
        |> modify()

      assert result == "counts = &Enum.count/1"
    end

    test "applied to an argument" do
      {:ok, [result]} =
        ~q{
        [[1, 2], [3, 4]] |> Enum.map(&Enum.counts/1)
      }
        |> modify()

      assert result == "[[1, 2], [3, 4]] |> Enum.map(&Enum.count/1)"
    end

    test "changing only a function from provided possible modules" do
      {:ok, [result]} =
        ~q{
        [&Enumerable.counts/1, &Enum.counts/1]
      }
        |> modify()

      assert result == "[&Enumerable.counts/1, &Enum.count/1]"
    end

    test "changing all occurrences of the function in the line" do
      {:ok, [result]} =
        ~q{
        [&Enum.counts/1, &Enum.counts/1]
      }
        |> modify()

      assert result == "[&Enum.count/1, &Enum.count/1]"
    end

    test "preserving the leading indent" do
      {:ok, [result]} = modify("     &Enum.counts/1", trim: false)

      assert result == "     &Enum.count/1"
    end

    if System.otp_release() |> String.to_integer() >= 23 do
      test "handles erlang functions" do
        message = """
        :ets.inserd/2 is undefined or private. Did you mean:
              * insert/2
              * insert_new/2
        """

        {:ok, [result]} =
          ~q{
          &:ets.inserd/2
        }
          |> modify(message: message, suggestion: ":ets.insert/2")

        assert result == "&:ets.insert/2"
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "when aliased" do
        message = """
        ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:

              * foo/1
        """

        {:ok, [result]} =
          ~q{
        alias ElixirLS.Test.RemoteFunction
        &RemoteFunction.fou/1
      }
          |> modify(message: message, suggestion: "RemoteFunction.foo", line: 1)

        assert result == "alias ElixirLS.Test.RemoteFunction\n&RemoteFunction.foo/1"
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "when aliased with a custom name" do
        message = """
        ElixirLS.Test.RemoteFunction.fou/1 is undefined or private. Did you mean:

              * foo/1
        """

        {:ok, [result]} =
          ~q{
        alias ElixirLS.Test.RemoteFunction, as: Remote
        &Remote.fou/1
      }
          |> modify(message: message, suggestion: "Remote.foo", line: 1)

        assert result == "alias ElixirLS.Test.RemoteFunction, as: Remote\n&Remote.foo/1"
      end
    end
  end
end
