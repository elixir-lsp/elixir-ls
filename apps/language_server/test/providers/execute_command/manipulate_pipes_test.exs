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

  describe "execute/2 to_pipe" do
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
                   "cursor_line" => 2,
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
                         "end" => %{"character" => 17, "line" => 2},
                         "start" => %{"character" => 4, "line" => 2}
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
                   "cursor_line" => 2,
                   "cursor_column" => 12,
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
                         "end" => %{"character" => 5, "line" => 5},
                         "start" => %{"character" => 4, "line" => 2}
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
                   "cursor_line" => 2,
                   "cursor_column" => 2,
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
                         "end" => %{"character" => 22, "line" => 2},
                         "start" => %{"character" => 3, "line" => 2}
                       }
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }
    end
  end

  describe "execute/2 from_pipe" do
    test "can unpipe remote calls in single lines" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          g(1) |> Kernel.+(1)
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
                   "cursor_line" => 2,
                   "cursor_column" => 8,
                   "operation" => "from_pipe"
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
                       "newText" => "Kernel.+(g(1), 1)",
                       "range" => %{
                         "end" => %{"character" => 22, "line" => 2},
                         "start" => %{"character" => 4, "line" => 2}
                       }
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }
    end

    test "can unpipe remote calls when there are multi-line args" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          x
          |> Kernel.+(
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
                   "cursor_column" => 5,
                   "operation" => "from_pipe"
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
                       "newText" => "Kernel.+(x, 1)",
                       "range" => %{
                         "end" => %{"character" => 5, "line" => 5},
                         "start" => %{"character" => 3, "line" => 2}
                       }
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }
    end

    test "can unpipe local calls in single line" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          h(x, 2) |> g(h(3, 4))
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
                   "cursor_line" => 2,
                   "cursor_column" => 11,
                   "operation" => "from_pipe"
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
                       "newText" => "g(h(x, 2), h(3, 4))",
                       "range" => %{
                         "end" => %{"character" => 24, "line" => 2},
                         "start" => %{"character" => 4, "line" => 2}
                       }
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }
    end
  end
end
