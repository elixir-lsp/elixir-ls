defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipesTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.{Server, SourceFile}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes
  alias ElixirLS.LanguageServer.Protocol.TextEdit

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

  describe "execute/2 toPipe" do
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

      assert_never_raises(text, uri, "toPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["toPipe", uri, 2, 13],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 18, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "x |> Kernel.+(1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          x |> Kernel.+(1)
          |> Kernel.+(2)
          |> g()
        end

        def g(y), do: y
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
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

      assert_never_raises(text, uri, "toPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["toPipe", uri, 2, 12],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 5, "line" => 5},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "x |> Kernel.+(1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          x |> Kernel.+(1)
          |> Kernel.+(2)
          |> g()
        end

        def g(y), do: y
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
    end

    test "to_pipe_at_cursor beginning of line" do
      text = """
      defmodule Demo do
        def my_fun(data) do
          Ash.Changeset.for_create(Track, :create, data)
          |> GenTracker.API.create()
        end
      end
      """

      expected_text = """
      defmodule Demo do
        def my_fun(data) do
          Track |> Ash.Changeset.for_create(:create, data)
          |> GenTracker.API.create()
        end
      end
      """

      {:ok, text_edit} = ManipulatePipes.to_pipe_at_cursor(text, 2, 4)

      edited_text = ElixirLS.LanguageServer.Test.TestUtils.apply_text_edit(text, text_edit)
      assert edited_text == expected_text
    end

    # Broken
    test "to_pipe_at_cursor end of line" do
      text = """
      defmodule Demo do
        def my_fun(data) do
          Ash.Changeset.for_create(Track, :create, data)
          |> GenTracker.API.create()
        end
      end
      """

      expected_text = """
      defmodule Demo do
        def my_fun(data) do
          Track |> Ash.Changeset.for_create(:create, data)
          |> GenTracker.API.create()
        end
      end
      """

      {:ok, text_edit} = ManipulatePipes.to_pipe_at_cursor(text, 2, 50)

      edited_text = ElixirLS.LanguageServer.Test.TestUtils.apply_text_edit(text, text_edit)
      assert edited_text == expected_text
    end

    test "to_pipe_at_cursor end of line" do
      text = """
      defmodule Demo do
        def my_fun(data) do
          Ash.Changeset.for_create(Track, :create, data)\s
          |> GenTracker.API.create()
        end
      end
      """

      expected_text = """
      defmodule Demo do
        def my_fun(data) do
          Track |> Ash.Changeset.for_create(:create, data)
          |> GenTracker.API.create()
        end
      end
      """

      {:ok, text_edit} = ManipulatePipes.to_pipe_at_cursor(text, 2, 50)

      edited_text = ElixirLS.LanguageServer.Test.TestUtils.apply_text_edit(text, text_edit)
      assert edited_text == expected_text
    end

    test "to_pipe_at_cursor near end of line" do
      text = """
      defmodule Demo do
        def my_fun(data) do
          Ash.Changeset.for_create(Track, :create, data)
          |> GenTracker.API.create()
        end
      end
      """

      expected_text = """
      defmodule Demo do
        def my_fun(data) do
          Track |> Ash.Changeset.for_create(:create, data)
          |> GenTracker.API.create()
        end
      end
      """

      {:ok, text_edit} = ManipulatePipes.to_pipe_at_cursor(text, 2, 49)

      edited_text = ElixirLS.LanguageServer.Test.TestUtils.apply_text_edit(text, text_edit)
      assert edited_text == expected_text
    end

    # Broken
    test "to_pipe_at_cursor at end of function (with another function after)" do
      text = """
      defmodule Demo do
        def my_fun(data) do
          Ash.Changeset.for_create(Track, :create, data)
          |> GenTracker.API.create()
        end

        def next_fun(), do: 42
      end
      """

      expected_text = """
      defmodule Demo do
        def my_fun(data) do
          Track |> Ash.Changeset.for_create(:create, data)
          |> GenTracker.API.create()
        end

        def next_fun(), do: 42
      end
      """

      {:ok, text_edit} = ManipulatePipes.to_pipe_at_cursor(text, 2, 49)

      edited_text = ElixirLS.LanguageServer.Test.TestUtils.apply_text_edit(text, text_edit)
      assert edited_text == expected_text
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

      assert_never_raises(text, uri, "toPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["toPipe", uri, 2, 2],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 23, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "h(x, 2) |> g(h(3, 4))"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          h(x, 2) |> g(h(3, 4))
          |> Kernel.+(2)
        end

        def g(x, y), do: x + y

        def h(a, b), do: a - b
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
    end

    for {line_sep, test_name_suffix} <- [{"\r\n", "\\r\\n"}, {"\n", "\\n"}] do
      test "can pipe correctly when the line separator is #{test_name_suffix}" do
        {:ok, _} =
          JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

        uri = "file:/some_file.ex"

        base_code = [
          "defmodule A do",
          "  def f(x)  do",
          "    Kernel.+(",
          "      x,",
          "      y",
          "    )",
          "    |> B.g()",
          "  end",
          "end"
        ]

        text = Enum.join(base_code, unquote(line_sep))

        assert_never_raises(text, uri, "toPipe")

        assert {:ok, nil} =
                 ManipulatePipes.execute(
                   ["toPipe", uri, 2, 12],
                   %Server{
                     source_files: %{
                       uri => %SourceFile{
                         text: text
                       }
                     }
                   }
                 )

        assert_receive {:request, "workspace/applyEdit", params}

        expected_range = %{
          "end" => %{"character" => 5, "line" => 5},
          "start" => %{"character" => 4, "line" => 2}
        }

        expected_substitution = "x |> Kernel.+(y)"

        assert params == %{
                 "edit" => %{
                   "changes" => %{
                     uri => [
                       %TextEdit{
                         newText: expected_substitution,
                         range: expected_range
                       }
                     ]
                   }
                 },
                 "label" => "Convert function call to pipe operator"
               }

        expected_base_code = [
          "defmodule A do",
          "  def f(x)  do",
          "    x |> Kernel.+(y)",
          "    |> B.g()",
          "  end",
          "end"
        ]

        edited_text = Enum.join(expected_base_code, unquote(line_sep))

        assert edited_text ==
                 ElixirLS.LanguageServer.SourceFile.apply_edit(
                   text,
                   expected_range,
                   expected_substitution
                 )
      end
    end

    test "can handle utf 16 characters" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          g("éééççç", x)
        end

        def g(a, b), do: a <> b
      end
      """

      assert_never_raises(text, uri, "toPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["toPipe", uri, 2, 14],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 18, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = ~s{"éééççç" |> g(x)}

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          "éééççç" |> g(x)
        end

        def g(a, b), do: a <> b
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
    end

    test "can handle multiple calls" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule BasicEx do
        def add(a) do
          require Logger

          Logger.info(to_string(add_num(a, 12)))
        end

        def add_num(a, num), do: a + num
      end
      """

      assert_never_raises(text, uri, "toPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["toPipe", uri, 4, 17],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 41, "line" => 4},
        "start" => %{"character" => 16, "line" => 4}
      }

      expected_substitution = "add_num(a, 12) |> to_string()"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert function call to pipe operator"
             }

      edited_text = """
      defmodule BasicEx do
        def add(a) do
          require Logger

          Logger.info(add_num(a, 12) |> to_string())
        end

        def add_num(a, num), do: a + num
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
    end
  end

  describe "execute/2 fromPipe" do
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

      assert_never_raises(text, uri, "fromPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["fromPipe", uri, 2, 8],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 23, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "Kernel.+(g(1), 1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert pipe operator to function call"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          Kernel.+(g(1), 1)
          |> Kernel.+(2)
          |> g()
        end

        def g(y), do: y
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
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

      assert_never_raises(text, uri, "fromPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["fromPipe", uri, 3, 5],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 5, "line" => 5},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "Kernel.+(x, 1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert pipe operator to function call"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          Kernel.+(x, 1)
          |> Kernel.+(2)
          |> g()
        end

        def g(y), do: y
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
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

      assert_never_raises(text, uri, "fromPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["fromPipe", uri, 2, 11],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 25, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "g(h(x, 2), h(3, 4))"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert pipe operator to function call"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          g(h(x, 2), h(3, 4))
          |> Kernel.+(2)
        end

        def g(x, y), do: x + y

        def h(a, b), do: a - b
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
    end

    for {line_sep, test_name_suffix} <- [{"\r\n", "\\r\\n"}, {"\n", "\\n"}] do
      test "can unpipe correctly when the line separator is #{test_name_suffix}" do
        {:ok, _} =
          JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

        uri = "file:/some_file.ex"

        base_code = [
          "defmodule A do",
          "  def f(x)  do",
          "    x",
          "    |> Kernel.+(y)",
          "    |> B.g()",
          "  end",
          "end"
        ]

        text = Enum.join(base_code, unquote(line_sep))

        assert_never_raises(text, uri, "fromPipe")

        assert {:ok, nil} =
                 ManipulatePipes.execute(
                   ["fromPipe", uri, 3, 4],
                   %Server{
                     source_files: %{
                       uri => %SourceFile{
                         text: text
                       }
                     }
                   }
                 )

        assert_receive {:request, "workspace/applyEdit", params}

        expected_range = %{
          "end" => %{"character" => 18, "line" => 3},
          "start" => %{"character" => 4, "line" => 2}
        }

        expected_substitution = "Kernel.+(x, y)"

        assert params == %{
                 "edit" => %{
                   "changes" => %{
                     uri => [
                       %TextEdit{
                         newText: expected_substitution,
                         range: expected_range
                       }
                     ]
                   }
                 },
                 "label" => "Convert pipe operator to function call"
               }

        expected_base_code = [
          "defmodule A do",
          "  def f(x)  do",
          "    Kernel.+(x, y)",
          "    |> B.g()",
          "  end",
          "end"
        ]

        edited_text = Enum.join(expected_base_code, unquote(line_sep))

        assert edited_text ==
                 ElixirLS.LanguageServer.SourceFile.apply_edit(
                   text,
                   expected_range,
                   expected_substitution
                 )
      end
    end

    test "can handle multiple calls in no-op execution" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule BasicEx do
        def add(a) do
          require Logger

          Logger.info(to_string(add_num(a, 12)))
        end

        def add_num(a, num), do: a + num
      end
      """

      assert_never_raises(text, uri, "fromPipe")

      assert {:error, :pipe_not_found} =
               ManipulatePipes.execute(
                 ["fromPipe", uri, 4, 16],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      refute_receive {:request, "workspace/applyEdit", _params}
    end

    test "can handle utf 16 characters" do
      {:ok, _} =
        JsonRpcMock.start_link(success_reply: {:ok, %{"applied" => true}}, test_pid: self())

      uri = "file:/some_file.ex"

      text = """
      defmodule A do
        def f(x) do
          x
          |> g("éééççç")
        end

        def g(a, b), do: a <> b
      end
      """

      assert_never_raises(text, uri, "fromPipe")

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 ["fromPipe", uri, 3, 5],
                 %Server{
                   source_files: %{
                     uri => %SourceFile{
                       text: text
                     }
                   }
                 }
               )

      assert_receive {:request, "workspace/applyEdit", params}

      expected_range = %{
        "end" => %{"character" => 18, "line" => 3},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = ~s{g(x, "éééççç")}

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %TextEdit{
                       newText: expected_substitution,
                       range: expected_range
                     }
                   ]
                 }
               },
               "label" => "Convert pipe operator to function call"
             }

      edited_text = """
      defmodule A do
        def f(x) do
          g(x, "éééççç")
        end

        def g(a, b), do: a <> b
      end
      """

      assert ElixirLS.LanguageServer.SourceFile.apply_edit(
               text,
               expected_range,
               expected_substitution
             ) == edited_text
    end
  end

  defp assert_never_raises(text, uri, command) do
    uri = Path.join(uri, "/assert_never_raises")

    for c <- String.graphemes(text), reduce: {0, 0} do
      {line, character} ->
        try do
          result =
            ManipulatePipes.execute(
              [command, uri, line, character],
              %Server{
                source_files: %{
                  uri => %SourceFile{
                    text: text
                  }
                }
              }
            )

          case result do
            {:ok, _} ->
              assert_receive {:request, _, _}

            _ ->
              nil
          end

          if c in ["\r\n", "\r", "\n"] do
            {line + 1, 0}
          else
            {line, character + 1}
          end
        rescue
          exception ->
            flunk("raised #{inspect(exception)}. line: #{line}, character: #{character}")
        end
    end
  end
end
