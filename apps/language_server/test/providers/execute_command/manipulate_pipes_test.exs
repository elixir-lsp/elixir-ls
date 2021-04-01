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

      expected_range = %{
        "end" => %{"character" => 18, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "x |> Kernel.+(1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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

      expected_range = %{
        "end" => %{"character" => 5, "line" => 5},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "x |> Kernel.+(1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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

      expected_range = %{
        "end" => %{"character" => 23, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "h(x, 2) |> g(h(3, 4))"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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

        expected_range = %{
          "end" => %{"character" => 5, "line" => 5},
          "start" => %{"character" => 4, "line" => 2}
        }

        expected_substitution = "x |> Kernel.+(y)"

        assert params == %{
                 "edit" => %{
                   "changes" => %{
                     uri => [
                       %{
                         "newText" => expected_substitution,
                         "range" => expected_range
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

      assert {:ok, nil} =
               ManipulatePipes.execute(
                 %{
                   "uri" => uri,
                   "cursor_line" => 2,
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

      expected_range = %{
        "end" => %{"character" => 18, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = ~s{"éééççç" |> g(x)}

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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

      expected_range = %{
        "end" => %{"character" => 23, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "Kernel.+(g(1), 1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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

      expected_range = %{
        "end" => %{"character" => 5, "line" => 5},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "Kernel.+(x, 1)"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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

      expected_range = %{
        "end" => %{"character" => 25, "line" => 2},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = "g(h(x, 2), h(3, 4))"

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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

        assert {:ok, nil} =
                 ManipulatePipes.execute(
                   %{
                     "uri" => uri,
                     "cursor_line" => 3,
                     "cursor_column" => 4,
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

        expected_range = %{
          "end" => %{"character" => 18, "line" => 3},
          "start" => %{"character" => 4, "line" => 2}
        }

        expected_substitution = "Kernel.+(x, y)"

        assert params == %{
                 "edit" => %{
                   "changes" => %{
                     uri => [
                       %{
                         "newText" => expected_substitution,
                         "range" => expected_range
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

      expected_range = %{
        "end" => %{"character" => 18, "line" => 3},
        "start" => %{"character" => 4, "line" => 2}
      }

      expected_substitution = ~s{g(x, "éééççç")}

      assert params == %{
               "edit" => %{
                 "changes" => %{
                   uri => [
                     %{
                       "newText" => expected_substitution,
                       "range" => expected_range
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
end
