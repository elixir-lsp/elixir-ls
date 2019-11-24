defmodule ElixirLS.LanguageServer.Providers.DocumentSymbolsTest do
  alias ElixirLS.LanguageServer.Providers.DocumentSymbols
  use ExUnit.Case

  test "returns symbol information" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule MyModule do
        @my_mod_var "module variable"
        def my_fn(arg), do: :ok
        defp my_private_fn(arg), do: :ok
        defmacro my_macro(), do: :ok
        defmacrop my_private_macro(), do: :ok
        defguard my_guard(a) when is_integer(a)
        defguardp my_private_guard(a) when is_integer(a)
        defdelegate my_delegate(list), to: Enum, as: :reverse
        defguard my_guard when 1 == 1
        def my_fn_no_arg, do: :ok
        def my_fn_with_guard(arg) when is_integer(arg), do: :ok
        def my_fn_with_more_blocks(arg) do
          :ok
        rescue
          e in ArgumentError -> :ok
        else
          _ -> :ok
        catch
          _ -> :ok
        after
          :ok
        end
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 14,
                    name: "@my_mod_var",
                    range: %{end: %{character: 9, line: 2}, start: %{character: 9, line: 2}},
                    selectionRange: %{
                      end: %{character: 9, line: 2},
                      start: %{character: 9, line: 2}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn(arg)",
                    range: %{end: %{character: 12, line: 3}, start: %{character: 12, line: 3}},
                    selectionRange: %{
                      end: %{character: 12, line: 3},
                      start: %{character: 12, line: 3}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_private_fn(arg)",
                    range: %{end: %{character: 13, line: 4}, start: %{character: 13, line: 4}},
                    selectionRange: %{
                      end: %{character: 13, line: 4},
                      start: %{character: 13, line: 4}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_macro()",
                    range: %{end: %{character: 17, line: 5}, start: %{character: 17, line: 5}},
                    selectionRange: %{
                      end: %{character: 17, line: 5},
                      start: %{character: 17, line: 5}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_private_macro()",
                    range: %{end: %{character: 18, line: 6}, start: %{character: 18, line: 6}},
                    selectionRange: %{
                      end: %{character: 18, line: 6},
                      start: %{character: 18, line: 6}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_guard(a) when is_integer(a)",
                    range: %{end: %{character: 29, line: 7}, start: %{character: 29, line: 7}},
                    selectionRange: %{
                      end: %{character: 29, line: 7},
                      start: %{character: 29, line: 7}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_private_guard(a) when is_integer(a)",
                    range: %{end: %{character: 38, line: 8}, start: %{character: 38, line: 8}},
                    selectionRange: %{
                      end: %{character: 38, line: 8},
                      start: %{character: 38, line: 8}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_delegate(list)",
                    range: %{end: %{character: 20, line: 9}, start: %{character: 20, line: 9}},
                    selectionRange: %{
                      end: %{character: 20, line: 9},
                      start: %{character: 20, line: 9}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_guard when 1 == 1",
                    range: %{end: %{character: 26, line: 10}, start: %{character: 26, line: 10}},
                    selectionRange: %{
                      end: %{character: 26, line: 10},
                      start: %{character: 26, line: 10}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn_no_arg",
                    range: %{end: %{character: 12, line: 11}, start: %{character: 12, line: 11}},
                    selectionRange: %{
                      end: %{character: 12, line: 11},
                      start: %{character: 12, line: 11}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn_with_guard(arg) when is_integer(arg)",
                    range: %{end: %{character: 34, line: 12}, start: %{character: 34, line: 12}},
                    selectionRange: %{
                      end: %{character: 34, line: 12},
                      start: %{character: 34, line: 12}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn_with_more_blocks(arg)",
                    range: %{end: %{character: 12, line: 13}, start: %{character: 12, line: 13}},
                    selectionRange: %{
                      end: %{character: 12, line: 13},
                      start: %{character: 12, line: 13}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}},
                selectionRange: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles nested module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule MyModule do
        defmodule SubModule do
          def my_fn(), do: :ok
        end
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [
                      %{
                        children: [],
                        kind: 12,
                        name: "my_fn()",
                        range: %{
                          end: %{character: 14, line: 3},
                          start: %{character: 14, line: 3}
                        },
                        selectionRange: %{
                          end: %{character: 14, line: 3},
                          start: %{character: 14, line: 3}
                        }
                      }
                    ],
                    kind: 2,
                    name: "SubModule",
                    range: %{
                      end: %{character: 8, line: 2},
                      start: %{character: 8, line: 2}
                    },
                    selectionRange: %{
                      end: %{character: 8, line: 2},
                      start: %{character: 8, line: 2}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                },
                selectionRange: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handels multiple module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule MyModule do
        def some_function(), do: :ok
      end
      defmodule MyOtherModule do
        def some_other_function(), do: :ok
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "some_function()",
                    range: %{
                      end: %{character: 12, line: 2},
                      start: %{character: 12, line: 2}
                    },
                    selectionRange: %{
                      end: %{character: 12, line: 2},
                      start: %{character: 12, line: 2}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                },
                selectionRange: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                }
              },
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "some_other_function()",
                    range: %{
                      end: %{character: 12, line: 5},
                      start: %{character: 12, line: 5}
                    },
                    selectionRange: %{
                      end: %{character: 12, line: 5},
                      start: %{character: 12, line: 5}
                    }
                  }
                ],
                kind: 2,
                name: "MyOtherModule",
                range: %{
                  end: %{character: 6, line: 4},
                  start: %{character: 6, line: 4}
                },
                selectionRange: %{
                  end: %{character: 6, line: 4},
                  start: %{character: 6, line: 4}
                }
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles elixir atom module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule :'Elixir.MyModule' do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn()",
                    range: %{end: %{character: 12, line: 2}, start: %{character: 12, line: 2}},
                    selectionRange: %{
                      end: %{character: 12, line: 2},
                      start: %{character: 12, line: 2}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}},
                selectionRange: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles unquoted module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule unquote(var) do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn()",
                    range: %{end: %{character: 12, line: 2}, start: %{character: 12, line: 2}},
                    selectionRange: %{
                      end: %{character: 12, line: 2},
                      start: %{character: 12, line: 2}
                    }
                  }
                ],
                kind: 2,
                name: "# unknown",
                range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}},
                selectionRange: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles erlang atom module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule :my_module do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn()",
                    range: %{end: %{character: 12, line: 2}, start: %{character: 12, line: 2}},
                    selectionRange: %{
                      end: %{character: 12, line: 2},
                      start: %{character: 12, line: 2}
                    }
                  }
                ],
                kind: 2,
                name: "my_module",
                range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}},
                selectionRange: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles nested module definitions with __MODULE__" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule __MODULE__ do
        defmodule __MODULE__.SubModule do
          def my_fn(), do: :ok
        end
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [
                      %{
                        children: [],
                        kind: 12,
                        name: "my_fn()",
                        range: %{end: %{character: 14, line: 3}, start: %{character: 14, line: 3}},
                        selectionRange: %{
                          end: %{character: 14, line: 3},
                          start: %{character: 14, line: 3}
                        }
                      }
                    ],
                    kind: 2,
                    name: "__MODULE__.SubModule",
                    range: %{end: %{character: 8, line: 2}, start: %{character: 8, line: 2}},
                    selectionRange: %{
                      end: %{character: 8, line: 2},
                      start: %{character: 8, line: 2}
                    }
                  }
                ],
                kind: 2,
                name: "__MODULE__",
                range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}},
                selectionRange: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles protocols and implementations" do
    uri = "file://project/file.ex"

    text = """
    defprotocol MyProtocol do
      @doc "Calculates the size"
      def size(data)
    end

    defimpl MyProtocol, for: BitString do
      def size(binary), do: byte_size(binary)
    end

    defimpl MyProtocol, for: [List, MyList] do
      def size(param), do: length(param)
    end
    """

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "size(data)",
                    range: %{end: %{character: 6, line: 2}, start: %{character: 6, line: 2}},
                    selectionRange: %{
                      end: %{character: 6, line: 2},
                      start: %{character: 6, line: 2}
                    }
                  }
                ],
                kind: 11,
                name: "MyProtocol",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              },
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "size(binary)",
                    range: %{end: %{character: 6, line: 6}, start: %{character: 6, line: 6}},
                    selectionRange: %{
                      end: %{character: 6, line: 6},
                      start: %{character: 6, line: 6}
                    }
                  }
                ],
                kind: 2,
                name: "MyProtocol, for: BitString",
                range: %{end: %{character: 0, line: 5}, start: %{character: 0, line: 5}},
                selectionRange: %{end: %{character: 0, line: 5}, start: %{character: 0, line: 5}}
              },
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "size(param)",
                    range: %{end: %{character: 6, line: 10}, start: %{character: 6, line: 10}},
                    selectionRange: %{
                      end: %{character: 6, line: 10},
                      start: %{character: 6, line: 10}
                    }
                  }
                ],
                kind: 2,
                name: "MyProtocol, for: [List, MyList]",
                range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 9}},
                selectionRange: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 9}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles module definitions with struct" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      defstruct [:prop]
    end
    """

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 23,
                    name: "struct",
                    range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}},
                    selectionRange: %{
                      end: %{character: 2, line: 1},
                      start: %{character: 2, line: 1}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles module definitions with exception" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyError do
      defexception [:message]
    end
    """

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 23,
                    name: "exception",
                    range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}},
                    selectionRange: %{
                      end: %{character: 2, line: 1},
                      start: %{character: 2, line: 1}
                    }
                  }
                ],
                kind: 2,
                name: "MyError",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles module definitions with typespecs" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      @type my_simple :: integer
      @type my_union :: integer | binary
      @typep my_simple_private :: integer
      @opaque my_simple_opaque :: integer
      @type my_with_args(key, value) :: [{key, value}]
      @type my_with_args_when(key, value) :: [{key, value}] when value: integer
    end
    """

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 5,
                    name: "my_simple",
                    range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}},
                    selectionRange: %{
                      end: %{character: 3, line: 1},
                      start: %{character: 3, line: 1}
                    }
                  },
                  %{
                    children: [],
                    kind: 5,
                    name: "my_union",
                    range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}},
                    selectionRange: %{
                      end: %{character: 3, line: 2},
                      start: %{character: 3, line: 2}
                    }
                  },
                  %{
                    children: [],
                    kind: 5,
                    name: "my_simple_private",
                    range: %{end: %{character: 3, line: 3}, start: %{character: 3, line: 3}},
                    selectionRange: %{
                      end: %{character: 3, line: 3},
                      start: %{character: 3, line: 3}
                    }
                  },
                  %{
                    children: [],
                    kind: 5,
                    name: "my_simple_opaque",
                    range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}},
                    selectionRange: %{
                      end: %{character: 3, line: 4},
                      start: %{character: 3, line: 4}
                    }
                  },
                  %{
                    children: [],
                    kind: 5,
                    name: "my_with_args(key, value)",
                    range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}},
                    selectionRange: %{
                      end: %{character: 3, line: 5},
                      start: %{character: 3, line: 5}
                    }
                  },
                  %{
                    children: [],
                    kind: 5,
                    name: "my_with_args_when(key, value)",
                    range: %{end: %{character: 3, line: 6}, start: %{character: 3, line: 6}},
                    selectionRange: %{
                      end: %{character: 3, line: 6},
                      start: %{character: 3, line: 6}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles module definitions with callbacks" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      @callback my_callback(type1, type2) :: return_type
      @macrocallback my_macrocallback(type1, type2) :: Macro.t

      @callback my_callback_when(type1, type2) :: return_type when type1: integer
      @macrocallback my_macrocallback_when(type1, type2) :: Macro.t when type1: integer, type2: binary

      @callback my_callback_no_arg() :: return_type
      @macrocallback my_macrocallback_no_arg() :: Macro.t
    end
    """

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 24,
                    name: "my_callback(type1, type2)",
                    range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}},
                    selectionRange: %{
                      end: %{character: 3, line: 1},
                      start: %{character: 3, line: 1}
                    }
                  },
                  %{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback(type1, type2)",
                    range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}},
                    selectionRange: %{
                      end: %{character: 3, line: 2},
                      start: %{character: 3, line: 2}
                    }
                  },
                  %{
                    children: [],
                    kind: 24,
                    name: "my_callback_when(type1, type2)",
                    range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}},
                    selectionRange: %{
                      end: %{character: 3, line: 4},
                      start: %{character: 3, line: 4}
                    }
                  },
                  %{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback_when(type1, type2)",
                    range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}},
                    selectionRange: %{
                      end: %{character: 3, line: 5},
                      start: %{character: 3, line: 5}
                    }
                  },
                  %{
                    children: [],
                    kind: 24,
                    name: "my_callback_no_arg()",
                    range: %{end: %{character: 3, line: 7}, start: %{character: 3, line: 7}},
                    selectionRange: %{
                      end: %{character: 3, line: 7},
                      start: %{character: 3, line: 7}
                    }
                  },
                  %{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback_no_arg()",
                    range: %{end: %{character: 3, line: 8}, start: %{character: 3, line: 8}},
                    selectionRange: %{
                      end: %{character: 3, line: 8},
                      start: %{character: 3, line: 8}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles funs with specs" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule MyModule do
        @spec my_fn(integer) :: atom
        def my_fn(a), do: :ok
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 24,
                    name: "my_fn(integer)",
                    range: %{end: %{character: 9, line: 2}, start: %{character: 9, line: 2}},
                    selectionRange: %{
                      end: %{character: 9, line: 2},
                      start: %{character: 9, line: 2}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn(a)",
                    range: %{end: %{character: 12, line: 3}, start: %{character: 12, line: 3}},
                    selectionRange: %{
                      end: %{character: 12, line: 3},
                      start: %{character: 12, line: 3}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}},
                selectionRange: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "skips docs attributes" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      @moduledoc ""
      @doc ""
      @typedoc ""
    end
    """

    assert {:ok,
            [
              %{
                children: [],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles various builtin attributes" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      @optional_callbacks non_vital_fun: 0, non_vital_macro: 1
      @behaviour MyBehaviour
      @impl true
      @derive [MyProtocol]
      @enforce_keys [:name]
      @compile {:inline, my_fun: 1}
      @deprecated ""
      @dialyzer {:nowarn_function, my_fun: 1}
      @file "hello.ex"
      @external_resource ""
      @on_load :load_check
      @on_definition :load_check
      @vsn "1.0"
      @after_compile __MODULE__
      @before_compile __MODULE__
      @fallback_to_any true
    end
    """

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 14,
                    name: "@optional_callbacks",
                    range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}},
                    selectionRange: %{
                      end: %{character: 3, line: 1},
                      start: %{character: 3, line: 1}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@behaviour",
                    range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}},
                    selectionRange: %{
                      end: %{character: 3, line: 2},
                      start: %{character: 3, line: 2}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@impl",
                    range: %{end: %{character: 3, line: 3}, start: %{character: 3, line: 3}},
                    selectionRange: %{
                      end: %{character: 3, line: 3},
                      start: %{character: 3, line: 3}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@derive",
                    range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}},
                    selectionRange: %{
                      end: %{character: 3, line: 4},
                      start: %{character: 3, line: 4}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@enforce_keys",
                    range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}},
                    selectionRange: %{
                      end: %{character: 3, line: 5},
                      start: %{character: 3, line: 5}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@compile",
                    range: %{end: %{character: 3, line: 6}, start: %{character: 3, line: 6}},
                    selectionRange: %{
                      end: %{character: 3, line: 6},
                      start: %{character: 3, line: 6}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@deprecated",
                    range: %{end: %{character: 3, line: 7}, start: %{character: 3, line: 7}},
                    selectionRange: %{
                      end: %{character: 3, line: 7},
                      start: %{character: 3, line: 7}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@dialyzer",
                    range: %{end: %{character: 3, line: 8}, start: %{character: 3, line: 8}},
                    selectionRange: %{
                      end: %{character: 3, line: 8},
                      start: %{character: 3, line: 8}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@file",
                    range: %{end: %{character: 3, line: 9}, start: %{character: 3, line: 9}},
                    selectionRange: %{
                      end: %{character: 3, line: 9},
                      start: %{character: 3, line: 9}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@external_resource",
                    range: %{end: %{character: 3, line: 10}, start: %{character: 3, line: 10}},
                    selectionRange: %{
                      end: %{character: 3, line: 10},
                      start: %{character: 3, line: 10}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@on_load",
                    range: %{end: %{character: 3, line: 11}, start: %{character: 3, line: 11}},
                    selectionRange: %{
                      end: %{character: 3, line: 11},
                      start: %{character: 3, line: 11}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@on_definition",
                    range: %{end: %{character: 3, line: 12}, start: %{character: 3, line: 12}},
                    selectionRange: %{
                      end: %{character: 3, line: 12},
                      start: %{character: 3, line: 12}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@vsn",
                    range: %{end: %{character: 3, line: 13}, start: %{character: 3, line: 13}},
                    selectionRange: %{
                      end: %{character: 3, line: 13},
                      start: %{character: 3, line: 13}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@after_compile",
                    range: %{end: %{character: 3, line: 14}, start: %{character: 3, line: 14}},
                    selectionRange: %{
                      end: %{character: 3, line: 14},
                      start: %{character: 3, line: 14}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@before_compile",
                    range: %{end: %{character: 3, line: 15}, start: %{character: 3, line: 15}},
                    selectionRange: %{
                      end: %{character: 3, line: 15},
                      start: %{character: 3, line: 15}
                    }
                  },
                  %{
                    children: [],
                    kind: 14,
                    name: "@fallback_to_any",
                    range: %{end: %{character: 3, line: 16}, start: %{character: 3, line: 16}},
                    selectionRange: %{
                      end: %{character: 3, line: 16},
                      start: %{character: 3, line: 16}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles exunit tests" do
    uri = "file://project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        test "does something", do: :ok
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [],
                    kind: 12,
                    name: "test \"does something\"",
                    range: %{
                      end: %{character: 8, line: 3},
                      start: %{character: 8, line: 3}
                    },
                    selectionRange: %{
                      end: %{character: 8, line: 3},
                      start: %{character: 8, line: 3}
                    }
                  }
                ],
                kind: 2,
                name: "MyModuleTest",
                range: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                },
                selectionRange: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end

  test "handles exunit descibe tests" do
    uri = "file://project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        describe "some descripton" do
          test "does something", do: :ok
        end
      end
    ]

    assert {:ok,
            [
              %{
                children: [
                  %{
                    children: [
                      %{
                        children: [],
                        kind: 12,
                        name: "test \"does something\"",
                        range: %{
                          end: %{character: 10, line: 4},
                          start: %{character: 10, line: 4}
                        },
                        selectionRange: %{
                          end: %{character: 10, line: 4},
                          start: %{character: 10, line: 4}
                        }
                      }
                    ],
                    kind: 12,
                    name: "describe \"some descripton\"",
                    range: %{
                      end: %{character: 8, line: 3},
                      start: %{character: 8, line: 3}
                    },
                    selectionRange: %{
                      end: %{character: 8, line: 3},
                      start: %{character: 8, line: 3}
                    }
                  }
                ],
                kind: 2,
                name: "MyModuleTest",
                range: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                },
                selectionRange: %{
                  end: %{character: 6, line: 1},
                  start: %{character: 6, line: 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end
end
