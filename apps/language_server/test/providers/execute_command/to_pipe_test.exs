defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ToPipeTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.{Server, SourceFile}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ToPipe

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

  test "can pipe remote calls in single lines" do
    {:ok, _} =
      JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

    uri = "file:///some_file.ex"

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
             ToPipe.execute(
               %{"uri" => uri, "cursor_line" => 3, "cursor_column" => 14},
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
                       "end" => %{"character" => 19, "line" => 3},
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

    uri = "file:///some_file.ex"

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
             ToPipe.execute(
               %{"uri" => uri, "cursor_line" => 3, "cursor_column" => 14},
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
end
