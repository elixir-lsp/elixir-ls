defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipesTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.{Server, SourceFile}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes

  defmodule JsonRpcMock do
    use GenServer

    def init(args), do: {:ok, args}

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: ElixirLS.LanguageServer.JsonRpc)
    end

    def handle_call(
          msg,
          _from,
          state
        ) do
      send(state[:test_pid], msg)

      if state[:should_fail] do
        {:reply, state[:error_reply], state}
      else
        {:reply, state[:success_reply], state}
      end
    end
  end

  describe "execute/2" do
    test "can pipe remote calls in single lines" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          Kernel.+(x, 1)
          |> Kernel.+(2)
          |> g()
        end

        def g(y), do: y
      end
      """

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 %{
                   "uri" => uri,
                   "cursor_line" => 3,
                   "cursor_column" => 14,
                   "operation" => "to_pipe"
                 },
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => "x |> Kernel.+(1)",
                       "range" => %{
                         "end" => %{"character" => 18, "line" => 3},
                         "start" => %{"character" => 5, "line" => 3}
                       }
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }
    end

    test "can pipe remote calls when there are multi-line args" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          Kernel.+(
            x,
            1
          )
          |> Kernel.+(2)
          |> g()
        end

        def g(y), do: y
      end
      """

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 %{
                   "uri" => uri,
                   "cursor_line" => 3,
                   "cursor_column" => 13,
                   "operation" => "to_pipe"
                 },
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => "x |> Kernel.+(1)",
                       "range" => %{
                         "end" => %{"character" => 5, "line" => 6},
                         "start" => %{"character" => 5, "line" => 3}
                       }
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }
    end

    test "can pipe local calls in single line" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          g(h(x, 2), h(3, 4))
          |> Kernel.+(2)
        end

        def g(x, y), do: x + y

        def h(a, b), do: a - b
      end
      """

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 %{
                   "uri" => uri,
                   "cursor_line" => 3,
                   "cursor_column" => 3,
                   "operation" => "to_pipe"
                 },
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => "h(x, 2) |> g(h(3, 4))",
                       "range" => %{
                         "end" => %{"character" => 23, "line" => 3},
                         "start" => %{"character" => 4, "line" => 3}
                       }
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }
    end
  end

  describe "to_pipe/1" do
    test "single-line selection with two args in named function" do
      assert_piped("A.B.C.a |> X.Y.Z.function_name(b)", "X.Y.Z.function_name(A.B.C.a, b)")
    end

    test "single-line selection with single arg in named function" do
      assert_piped("A.B.C.a |> X.Y.Z.function_name()", "X.Y.Z.function_name(A.B.C.a)")
    end

    test "single-line selection with two args in anonymous function" do
      assert_piped("A.B.C.a |> X.Y.Z.function_name.(b)", "X.Y.Z.function_name.(A.B.C.a, b)")
    end

    test "single-line selection with single arg in anonymous function" do
      assert_piped("A.B.C.a |> function_name.()", "function_name.(A.B.C.a)")
    end

    test "multi-line selection with two args in named function" do
      assert_piped("X.Y.Z.a |> X.Y.Z.function_name(b, c)", """
        X.Y.Z.function_name(
        X.Y.Z.a,
        b,
        c
      )
      """)
    end
  end

  defp assert_piped(expected, input) do
    assert expected ==
             input
             |> Code.string_to_quoted!()
             |> ManipulatePipes.to_pipe()
             |> Macro.to_string()
  end
end
