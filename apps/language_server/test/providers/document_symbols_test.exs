defmodule ElixirLS.LanguageServer.Providers.DocumentSymbolsTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.DocumentSymbols
  alias ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder

  test "returns hierarchical symbol information" do
    uri = "file:///project/file.ex"
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
        def fun_multiple_when(term \\ nil)
        def fun_multiple_when(term)
            when is_integer(term)
            when is_float(term)
            when is_nil(term) do
          :maybe_number
        end
        def fun_multiple_when(_other) do
          :something_else
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@my_mod_var",
                    range: %{
                      "end" => %{"character" => 37, "line" => 2},
                      "start" => %{"character" => 8, "line" => 2}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 37, "line" => 2},
                      "start" => %{"character" => 8, "line" => 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn(arg)",
                    range: %{
                      "end" => %{"character" => 31, "line" => 3},
                      "start" => %{"character" => 8, "line" => 3}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 22, "line" => 3},
                      "start" => %{"character" => 12, "line" => 3}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defp my_private_fn(arg)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defmacro my_macro()"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defmacrop my_private_macro()"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defguard my_guard(a)",
                    range: %{
                      "end" => %{"character" => 47, "line" => 7},
                      "start" => %{"character" => 8, "line" => 7}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 28, "line" => 7},
                      "start" => %{"character" => 17, "line" => 7}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defguardp my_private_guard(a)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defdelegate my_delegate(list)",
                    range: %{
                      "end" => %{"character" => 61, "line" => 9},
                      "start" => %{"character" => 8, "line" => 9}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 37, "line" => 9},
                      "start" => %{"character" => 20, "line" => 9}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defguard my_guard"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn_no_arg",
                    range: %{
                      "end" => %{"character" => 33, "line" => 11},
                      "start" => %{"character" => 8, "line" => 11}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 24, "line" => 11},
                      "start" => %{"character" => 12, "line" => 11}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn_with_guard(arg)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn_with_more_blocks(arg)",
                    range: %{
                      "end" => %{"character" => 11, "line" => 23},
                      "start" => %{"character" => 8, "line" => 13}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 39, "line" => 13},
                      "start" => %{"character" => 12, "line" => 13}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def fun_multiple_when(term \\\\ nil)",
                    range: %{
                      "end" => %{"character" => 42, "line" => 24},
                      "start" => %{"character" => 8, "line" => 24}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 42, "line" => 24},
                      "start" => %{"character" => 12, "line" => 24}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def fun_multiple_when(term)",
                    range: %{
                      "end" => %{"character" => 11, "line" => 30},
                      "start" => %{"character" => 8, "line" => 25}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 35, "line" => 25},
                      "start" => %{"character" => 12, "line" => 25}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def fun_multiple_when(_other)",
                    range: %{
                      "end" => %{"character" => 11, "line" => 33},
                      "start" => %{"character" => 8, "line" => 31}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 37, "line" => 31},
                      "start" => %{"character" => 12, "line" => 31}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  "end" => %{"character" => 9, "line" => 34},
                  "start" => %{"character" => 6, "line" => 1}
                },
                selectionRange: %{
                  "end" => %{"character" => 24, "line" => 1},
                  "start" => %{"character" => 16, "line" => 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "returns flat symbol information" do
    uri = "file:///project/file.ex"
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

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 24},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "@my_mod_var",
                kind: 14,
                location: %{
                  range: %{
                    "end" => %{"character" => 37, "line" => 2},
                    "start" => %{"character" => 8, "line" => 2}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn(arg)",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 31, "line" => 3},
                    "start" => %{"character" => 8, "line" => 3}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defp my_private_fn(arg)",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defmacro my_macro()",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defmacrop my_private_macro()",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defguard my_guard(a)",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 47, "line" => 7},
                    "start" => %{"character" => 8, "line" => 7}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defguardp my_private_guard(a)",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defdelegate my_delegate(list)",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 61, "line" => 9},
                    "start" => %{"character" => 8, "line" => 9}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defguard my_guard",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn_no_arg",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn_with_guard(arg)",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn_with_more_blocks(arg)",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 11, "line" => 23},
                    "start" => %{"character" => 8, "line" => 13}
                  }
                },
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles nested module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        defmodule Sub.Module do
          def my_fn(), do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "def my_fn()"
                      }
                    ],
                    kind: 2,
                    name: "Sub.Module",
                    range: %{
                      "end" => %{"character" => 11, "line" => 4},
                      "start" => %{"character" => 8, "line" => 2}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 28, "line" => 2},
                      "start" => %{"character" => 18, "line" => 2}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  "end" => %{"character" => 9, "line" => 5},
                  "start" => %{"character" => 6, "line" => 1}
                },
                selectionRange: %{
                  "end" => %{"character" => 24, "line" => 1},
                  "start" => %{"character" => 16, "line" => 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles nested module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        defmodule SubModule do
          def my_fn(), do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 5},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "SubModule",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 11, "line" => 4},
                    "start" => %{"character" => 8, "line" => 2}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def my_fn()",
                containerName: "SubModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles multiple module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        def some_function(), do: :ok
      end
      defmodule MyOtherModule do
        def some_other_function(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def some_function()"
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  "end" => %{"character" => 9, "line" => 3},
                  "start" => %{"character" => 6, "line" => 1}
                },
                selectionRange: %{
                  "end" => %{"character" => 24, "line" => 1},
                  "start" => %{"character" => 16, "line" => 1}
                }
              },
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def some_other_function()"
                  }
                ],
                kind: 2,
                name: "MyOtherModule",
                range: %{
                  "end" => %{"character" => 9, "line" => 6},
                  "start" => %{"character" => 6, "line" => 4}
                },
                selectionRange: %{
                  "end" => %{"character" => 29, "line" => 4},
                  "start" => %{"character" => 16, "line" => 4}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles multiple module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        def some_function(), do: :ok
      end
      defmodule MyOtherModule do
        def some_other_function(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 3},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "def some_function()",
                kind: 12,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "MyOtherModule",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 6},
                    "start" => %{"character" => 6, "line" => 4}
                  }
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def some_other_function()",
                containerName: "MyOtherModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles elixir atom module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule :'Elixir.MyModule' do
        def my_fn(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn()"
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  "end" => %{"character" => 9, "line" => 3},
                  "start" => %{"character" => 6, "line" => 1}
                },
                selectionRange: %{
                  "end" => %{"character" => 9, "line" => 3},
                  "start" => %{"character" => 6, "line" => 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles elixir atom module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule :'Elixir.MyModule' do
        def my_fn(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 3},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "def my_fn()",
                kind: 12,
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles unquoted module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule unquote(var) do
        def my_fn(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn()"
                  }
                ],
                kind: 2,
                name: "# unknown",
                range: %{
                  "end" => %{"character" => 9, "line" => 3},
                  "start" => %{"character" => 6, "line" => 1}
                },
                selectionRange: %{
                  "end" => %{"character" => 28, "line" => 1},
                  "start" => %{"character" => 16, "line" => 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles unquoted module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule unquote(var) do
        def my_fn(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "# unknown",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 3},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def my_fn()",
                containerName: "# unknown"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles erlang atom module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule :my_module do
        def my_fn(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn()"
                  }
                ],
                kind: 2,
                name: "my_module",
                range: %{
                  "end" => %{"character" => 9, "line" => 3},
                  "start" => %{"character" => 6, "line" => 1}
                },
                selectionRange: %{
                  "end" => %{"character" => 9, "line" => 3},
                  "start" => %{"character" => 6, "line" => 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles erlang atom module definitions" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule :my_module do
        def my_fn(), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "my_module",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 3},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "def my_fn()",
                kind: 12,
                containerName: "my_module"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles nested module definitions with __MODULE__" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule __MODULE__ do
        defmodule __MODULE__.SubModule do
          def my_fn(), do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "def my_fn()"
                      }
                    ],
                    kind: 2,
                    name: "__MODULE__.SubModule"
                  }
                ],
                kind: 2,
                name: "__MODULE__"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles nested module definitions with __MODULE__" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule __MODULE__ do
        defmodule __MODULE__.SubModule do
          def my_fn(), do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "__MODULE__",
                kind: 2
              },
              %Protocol.SymbolInformation{
                name: "__MODULE__.SubModule",
                kind: 2,
                containerName: "__MODULE__"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn()",
                kind: 12,
                containerName: "__MODULE__.SubModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles protocols and implementations" do
    uri = "file:///project/file.ex"

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

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def size(data)",
                    range: %{
                      "end" => %{"character" => 16, "line" => 2},
                      "start" => %{"character" => 2, "line" => 2}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 16, "line" => 2},
                      "start" => %{"character" => 6, "line" => 2}
                    }
                  }
                ],
                kind: 11,
                name: "MyProtocol",
                range: %{
                  "end" => %{"character" => 3, "line" => 3},
                  "start" => %{"character" => 0, "line" => 0}
                },
                selectionRange: %{
                  "end" => %{"character" => 22, "line" => 0},
                  "start" => %{"character" => 12, "line" => 0}
                }
              },
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def size(binary)",
                    range: %{
                      "end" => %{"character" => 41, "line" => 6},
                      "start" => %{"character" => 2, "line" => 6}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 18, "line" => 6},
                      "start" => %{"character" => 6, "line" => 6}
                    }
                  }
                ],
                kind: 2,
                name: "MyProtocol, for: BitString",
                range: %{
                  "end" => %{"character" => 3, "line" => 7},
                  "start" => %{"character" => 0, "line" => 5}
                },
                selectionRange: %{
                  "end" => %{"character" => 3, "line" => 7},
                  "start" => %{"character" => 0, "line" => 5}
                }
              },
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def size(param)",
                    range: %{
                      "end" => %{"character" => 36, "line" => 10},
                      "start" => %{"character" => 2, "line" => 10}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 17, "line" => 10},
                      "start" => %{"character" => 6, "line" => 10}
                    }
                  }
                ],
                kind: 2,
                name: "MyProtocol, for: [List, MyList]",
                range: %{
                  "end" => %{"character" => 3, "line" => 11},
                  "start" => %{"character" => 0, "line" => 9}
                },
                selectionRange: %{
                  "end" => %{"character" => 3, "line" => 11},
                  "start" => %{"character" => 0, "line" => 9}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles protocols and implementations" do
    uri = "file:///project/file.ex"

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

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyProtocol",
                kind: 11,
                location: %{
                  range: %{
                    "end" => %{"character" => 3, "line" => 3},
                    "start" => %{"character" => 0, "line" => 0}
                  }
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def size(data)",
                location: %{
                  range: %{
                    "end" => %{"character" => 16, "line" => 2},
                    "start" => %{"character" => 2, "line" => 2}
                  }
                },
                containerName: "MyProtocol"
              },
              %Protocol.SymbolInformation{
                kind: 2,
                name: "MyProtocol, for: BitString",
                location: %{
                  range: %{
                    "end" => %{"character" => 3, "line" => 7},
                    "start" => %{"character" => 0, "line" => 5}
                  }
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def size(binary)",
                location: %{
                  range: %{
                    "end" => %{"character" => 41, "line" => 6},
                    "start" => %{"character" => 2, "line" => 6}
                  }
                },
                containerName: "MyProtocol, for: BitString"
              },
              %Protocol.SymbolInformation{
                kind: 2,
                name: "MyProtocol, for: [List, MyList]",
                location: %{
                  range: %{
                    "end" => %{"character" => 3, "line" => 11},
                    "start" => %{"character" => 0, "line" => 9}
                  }
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def size(param)",
                location: %{
                  range: %{
                    "end" => %{"character" => 36, "line" => 10},
                    "start" => %{"character" => 2, "line" => 10}
                  }
                },
                containerName: "MyProtocol, for: [List, MyList]"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles module definitions with struct" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      defstruct [:prop, prop_with_def: nil]
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "prop",
                        range: %{
                          "end" => %{"character" => 2, "line" => 1},
                          "start" => %{"character" => 2, "line" => 1}
                        },
                        selectionRange: %{
                          "end" => %{"character" => 2, "line" => 1},
                          "start" => %{"character" => 2, "line" => 1}
                        }
                      },
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "prop_with_def",
                        range: %{
                          "end" => %{"character" => 2, "line" => 1},
                          "start" => %{"character" => 2, "line" => 1}
                        },
                        selectionRange: %{
                          "end" => %{"character" => 2, "line" => 1},
                          "start" => %{"character" => 2, "line" => 1}
                        }
                      }
                    ],
                    kind: 23,
                    name: "defstruct MyModule",
                    range: %{
                      "end" => %{"character" => 39, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 39, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles module definitions with struct" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      defstruct [:prop, prop_with_def: nil]
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %Protocol.SymbolInformation{
                name: "defstruct MyModule",
                kind: 23,
                location: %{
                  range: %{
                    "end" => %{"character" => 39, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "prop",
                kind: 7,
                location: %{
                  range: %{
                    "end" => %{"character" => 2, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "defstruct MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 7,
                name: "prop_with_def",
                location: %{
                  range: %{
                    "end" => %{"character" => 2, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "defstruct MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles module definitions with exception" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyError do
      defexception [:message]
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "message",
                        range: %{
                          "end" => %{"character" => 2, "line" => 1},
                          "start" => %{"character" => 2, "line" => 1}
                        },
                        selectionRange: %{
                          "end" => %{"character" => 2, "line" => 1},
                          "start" => %{"character" => 2, "line" => 1}
                        }
                      }
                    ],
                    kind: 23,
                    name: "defexception MyError",
                    range: %{
                      "end" => %{"character" => 25, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 25, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    }
                  }
                ],
                kind: 2,
                name: "MyError"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles module definitions with exception" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyError do
      defexception [:message]
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyError",
                kind: 2
              },
              %Protocol.SymbolInformation{
                kind: 23,
                name: "defexception MyError",
                location: %{
                  range: %{
                    "end" => %{"character" => 25, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "MyError"
              },
              %Protocol.SymbolInformation{
                kind: 7,
                name: "message",
                location: %{
                  range: %{
                    "end" => %{"character" => 2, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "defexception MyError"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles module definitions with typespecs" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      @type my_simple :: integer
      @type my_union :: integer | binary
      @typep my_simple_private :: integer
      @opaque my_simple_opaque :: integer
      @type my_with_args(key, value) :: [{key, value}]
      @type my_with_args_when(key, value) :: [{key, value}] when value: integer
      @type abc
      @type
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %{
                    children: [],
                    kind: 5,
                    name: "@type my_simple",
                    range: %{
                      "end" => %{"character" => 28, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 17, "line" => 1},
                      "start" => %{"character" => 8, "line" => 1}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "@type my_union"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "@typep my_simple_private"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "@opaque my_simple_opaque"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "@type my_with_args(key, value)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "@type my_with_args_when(key, value)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "@type abc"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@type"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles module definitions with typespecs" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      @type my_simple :: integer
      @type my_union :: integer | binary
      @typep my_simple_private :: integer
      @opaque my_simple_opaque :: integer
      @type my_with_args(key, value) :: [{key, value}]
      @type my_with_args_when(key, value) :: [{key, value}] when value: integer
      @type abc
      @type
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "@type my_simple",
                location: %{
                  range: %{
                    "end" => %{"character" => 28, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "@type my_union",
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "@typep my_simple_private",
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "@opaque my_simple_opaque",
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "@type my_with_args(key, value)",
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "@type my_with_args_when(key, value)",
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "@type abc",
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 14,
                name: "@type",
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles module definitions with callbacks" do
    uri = "file:///project/file.ex"

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

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "@callback my_callback(type1, type2)",
                    range: %{
                      "end" => %{"character" => 52, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 37, "line" => 1},
                      "start" => %{"character" => 12, "line" => 1}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "@macrocallback my_macrocallback(type1, type2)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "@callback my_callback_when(type1, type2)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "@macrocallback my_macrocallback_when(type1, type2)"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "@callback my_callback_no_arg()"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "@macrocallback my_macrocallback_no_arg()"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles module definitions with callbacks" do
    uri = "file:///project/file.ex"

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

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %Protocol.SymbolInformation{
                name: "@callback my_callback(type1, type2)",
                kind: 24,
                location: %{
                  range: %{
                    "end" => %{"character" => 52, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@macrocallback my_macrocallback(type1, type2)",
                kind: 24,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@callback my_callback_when(type1, type2)",
                kind: 24,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@macrocallback my_macrocallback_when(type1, type2)",
                kind: 24,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@callback my_callback_no_arg()",
                kind: 24,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@macrocallback my_macrocallback_no_arg()",
                kind: 24,
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles funs with specs" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        @spec my_fn(integer) :: atom
        def my_fn(a), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn(a)"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles funs with specs" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        @spec my_fn(integer) :: atom
        def my_fn(a), do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %Protocol.SymbolInformation{
                name: "def my_fn(a)",
                kind: 12,
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles records" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        require Record
        Record.defrecord(:user, name: "meg", age: "25")
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    result = DocumentSymbols.symbols(uri, parser_context, true)

    # earlier elixir versions return different ranges
    if Version.match?(System.version(), ">= 1.13.0") do
      assert {:ok,
              [
                %Protocol.DocumentSymbol{
                  children: [
                    %Protocol.DocumentSymbol{
                      children: [
                        %Protocol.DocumentSymbol{
                          children: [],
                          kind: 7,
                          name: "name",
                          range: %{
                            "end" => %{"character" => 55, "line" => 3},
                            "start" => %{"character" => 15, "line" => 3}
                          },
                          selectionRange: %{
                            "end" => %{"character" => 55, "line" => 3},
                            "start" => %{"character" => 15, "line" => 3}
                          }
                        },
                        %Protocol.DocumentSymbol{
                          children: [],
                          kind: 7,
                          name: "age",
                          range: %{
                            "end" => %{"character" => 55, "line" => 3},
                            "start" => %{"character" => 15, "line" => 3}
                          },
                          selectionRange: %{
                            "end" => %{"character" => 55, "line" => 3},
                            "start" => %{"character" => 15, "line" => 3}
                          }
                        }
                      ],
                      kind: 5,
                      name: "defrecord :user",
                      range: %{
                        "end" => %{"character" => 55, "line" => 3},
                        "start" => %{"character" => 8, "line" => 3}
                      },
                      selectionRange: %{
                        "end" => %{"character" => 55, "line" => 3},
                        "start" => %{"character" => 8, "line" => 3}
                      }
                    }
                  ],
                  kind: 2,
                  name: "MyModule"
                }
              ]} = result
    end
  end

  test "[flat] handles records" do
    uri = "file:///project/file.ex"
    text = ~S[
      defmodule MyModule do
        require Record
        Record.defrecord(:user, name: "meg", age: "25")
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    result = DocumentSymbols.symbols(uri, parser_context, false)

    # earlier elixir versions return different ranges
    if Version.match?(System.version(), ">= 1.13.0") do
      assert {:ok,
              [
                %Protocol.SymbolInformation{
                  name: "MyModule",
                  kind: 2,
                  location: %{
                    range: %{
                      "end" => %{"character" => 9, "line" => 4},
                      "start" => %{"character" => 6, "line" => 1}
                    }
                  }
                },
                %Protocol.SymbolInformation{
                  name: "defrecord :user",
                  kind: 5,
                  containerName: "MyModule"
                },
                %Protocol.SymbolInformation{
                  containerName: "defrecord :user",
                  kind: 7,
                  location: %{
                    range: %{
                      "end" => %{"character" => 55, "line" => 3},
                      "start" => %{"character" => 15, "line" => 3}
                    },
                    uri: "file:///project/file.ex"
                  },
                  name: "name"
                },
                %Protocol.SymbolInformation{
                  containerName: "defrecord :user",
                  kind: 7,
                  location: %{
                    range: %{
                      "end" => %{"character" => 55, "line" => 3},
                      "start" => %{"character" => 15, "line" => 3}
                    },
                    uri: "file:///project/file.ex"
                  },
                  name: "age"
                }
              ]} = result
    end
  end

  test "[nested] skips docs attributes" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      @moduledoc ""
      @doc ""
      @typedoc ""
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [],
                kind: 2,
                name: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] skips docs attributes" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      @moduledoc ""
      @doc ""
      @typedoc ""
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles various builtin attributes" do
    uri = "file:///project/file.ex"

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
      @impl MyBehaviour
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@optional_callbacks",
                    range: %{
                      "end" => %{"character" => 58, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 58, "line" => 1},
                      "start" => %{"character" => 2, "line" => 1}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 11,
                    name: "@behaviour MyBehaviour"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@derive"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@enforce_keys"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@compile"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@dialyzer"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@file"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@external_resource"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@on_load"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@on_definition"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@vsn"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@after_compile"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@before_compile"
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@fallback_to_any"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles various builtin attributes" do
    uri = "file:///project/file.ex"

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
      @impl MyBehaviour
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 3, "line" => 18},
                    "start" => %{"character" => 0, "line" => 0}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "@optional_callbacks",
                kind: 14,
                location: %{
                  range: %{
                    "end" => %{"character" => 58, "line" => 1},
                    "start" => %{"character" => 2, "line" => 1}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@behaviour MyBehaviour",
                kind: 11,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@derive",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@enforce_keys",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@compile",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@dialyzer",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@file",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@external_resource",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@on_load",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@on_definition",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@vsn",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@after_compile",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@before_compile",
                kind: 14,
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@fallback_to_any",
                kind: 14,
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles exunit tests" do
    uri = "file:///project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        test "does something", do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "test \"does something\"",
                    range: %{
                      "end" => %{"character" => 38, "line" => 3},
                      "start" => %{"character" => 8, "line" => 3}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 38, "line" => 3},
                      "start" => %{"character" => 8, "line" => 3}
                    }
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles exunit tests" do
    uri = "file:///project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        test "does something", do: :ok
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 4},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "test \"does something\"",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 38, "line" => 3},
                    "start" => %{"character" => 8, "line" => 3}
                  }
                },
                containerName: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles exunit describe tests" do
    uri = "file:///project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        describe "some description" do
          test "does something", do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "test \"does something\"",
                        range: %{
                          "end" => %{"character" => 10, "line" => 4},
                          "start" => %{"character" => 10, "line" => 4}
                        },
                        selectionRange: %{
                          "end" => %{"character" => 10, "line" => 4},
                          "start" => %{"character" => 10, "line" => 4}
                        }
                      }
                    ],
                    kind: 12,
                    name: "describe \"some description\"",
                    range: %{
                      "end" => %{"character" => 11, "line" => 5},
                      "start" => %{"character" => 8, "line" => 3}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 11, "line" => 5},
                      "start" => %{"character" => 8, "line" => 3}
                    }
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[nested] handles exunit describes and tests with unevaluated names" do
    uri = "file:///project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        describe ~S(some "description") do
          test "does" <> "something", do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "test \"does\" <> \"something\"",
                        range: %{
                          "end" => %{"character" => 10, "line" => 4},
                          "start" => %{"character" => 10, "line" => 4}
                        },
                        selectionRange: %{
                          "end" => %{"character" => 10, "line" => 4},
                          "start" => %{"character" => 10, "line" => 4}
                        }
                      }
                    ],
                    kind: 12,
                    name: describe_sigil,
                    range: %{
                      "end" => %{"character" => 11, "line" => 5},
                      "start" => %{"character" => 8, "line" => 3}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 11, "line" => 5},
                      "start" => %{"character" => 8, "line" => 3}
                    }
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)

    assert describe_sigil == "describe ~S(some \"description\")"
  end

  test "[flat] handles exunit describe tests" do
    uri = "file:///project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        describe "some description" do
          test "does something", do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 6},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "describe \"some description\"",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 11, "line" => 5},
                    "start" => %{"character" => 8, "line" => 3}
                  }
                },
                containerName: "MyModuleTest"
              },
              %Protocol.SymbolInformation{
                name: "test \"does something\"",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 10, "line" => 4},
                    "start" => %{"character" => 10, "line" => 4}
                  }
                },
                containerName: "describe \"some description\""
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[flat] handles exunit describes and tests with unevaluated names" do
    uri = "file:///project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        describe ~S(some "description") do
          test "does" <> "something", do: :ok
        end
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 9, "line" => 6},
                    "start" => %{"character" => 6, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: describe_sigil,
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 11, "line" => 5},
                    "start" => %{"character" => 8, "line" => 3}
                  }
                },
                containerName: "MyModuleTest"
              },
              %Protocol.SymbolInformation{
                name: "test \"does\" <> \"something\"",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 10, "line" => 4},
                    "start" => %{"character" => 10, "line" => 4}
                  }
                },
                containerName: describe_sigil
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)

    assert describe_sigil == "describe ~S(some \"description\")"
  end

  test "[nested] handles exunit callbacks" do
    uri = "file:///project/test.exs"

    text = """
    defmodule MyModuleTest do
      use ExUnit.Case
      setup do
        [conn: Plug.Conn.build_conn()]
      end
      setup :clean_up_tmp_directory
      setup_all do
        :ok
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup",
                    range: %{
                      "end" => %{"character" => 5, "line" => 4},
                      "start" => %{"character" => 2, "line" => 2}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 5, "line" => 4},
                      "start" => %{"character" => 2, "line" => 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup",
                    range: %{
                      "end" => %{"character" => 31, "line" => 5},
                      "start" => %{"character" => 2, "line" => 5}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 31, "line" => 5},
                      "start" => %{"character" => 2, "line" => 5}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup_all",
                    range: %{
                      "end" => %{"character" => 5, "line" => 8},
                      "start" => %{"character" => 2, "line" => 6}
                    },
                    selectionRange: %{
                      "end" => %{"character" => 5, "line" => 8},
                      "start" => %{"character" => 2, "line" => 6}
                    }
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles exunit callbacks" do
    uri = "file:///project/test.exs"

    text = """
    defmodule MyModuleTest do
      use ExUnit.Case
      setup do
        [conn: Plug.Conn.build_conn()]
      end
      setup :clean_up_tmp_directory
      setup_all do
        :ok
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: %{
                    "end" => %{"character" => 3, "line" => 9},
                    "start" => %{"character" => 0, "line" => 0}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "setup",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 5, "line" => 4},
                    "start" => %{"character" => 2, "line" => 2}
                  }
                },
                containerName: "MyModuleTest"
              },
              %Protocol.SymbolInformation{
                name: "setup",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 31, "line" => 5},
                    "start" => %{"character" => 2, "line" => 5}
                  }
                },
                containerName: "MyModuleTest"
              },
              %Protocol.SymbolInformation{
                name: "setup_all",
                kind: 12,
                location: %{
                  range: %{
                    "end" => %{"character" => 5, "line" => 8},
                    "start" => %{"character" => 2, "line" => 6}
                  }
                },
                containerName: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles config" do
    uri = "file:///project/test.exs"

    text = """
    import Config
    config :logger, :console,
       level: :info,
       format: "$date $time [$level] $metadata$message\n",
       metadata: [:user_id]
    config :app, :key, :value
    config :my_app,
      ecto_repos: [MyApp.Repo]
    config :my_app, MyApp.Repo,
      migration_timestamps: [type: :naive_datetime_usec],
      username: "postgres"
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :logger :console",
                range: %{
                  "end" => %{"character" => 23, "line" => 5},
                  "start" => %{"character" => 0, "line" => 1}
                },
                selectionRange: %{
                  "end" => %{"character" => 23, "line" => 5},
                  "start" => %{"character" => 0, "line" => 1}
                }
              },
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :app :key",
                range: %{
                  "end" => %{"character" => 25, "line" => 6},
                  "start" => %{"character" => 0, "line" => 6}
                },
                selectionRange: %{
                  "end" => %{"character" => 25, "line" => 6},
                  "start" => %{"character" => 0, "line" => 6}
                }
              },
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :my_app [:ecto_repos]",
                range: %{
                  "end" => %{"character" => 26, "line" => 8},
                  "start" => %{"character" => 0, "line" => 7}
                },
                selectionRange: %{
                  "end" => %{"character" => 26, "line" => 8},
                  "start" => %{"character" => 0, "line" => 7}
                }
              },
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :my_app MyApp.Repo",
                range: %{
                  "end" => %{"character" => 0, "line" => 9},
                  "start" => %{"character" => 0, "line" => 9}
                },
                selectionRange: %{
                  "end" => %{"character" => 0, "line" => 9},
                  "start" => %{"character" => 0, "line" => 9}
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "[flat] handles config" do
    uri = "file:///project/test.exs"

    text = """
    import Config
    config :logger, :console,
       level: :info,
       format: "$date $time [$level] $metadata$message\n",
       metadata: [:user_id]
    config :app, :key, :value
    config :my_app,
      ecto_repos: [MyApp.Repo]
    config :my_app, MyApp.Repo,
      migration_timestamps: [type: :naive_datetime_usec],
      username: "postgres"
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "config :logger :console",
                kind: 20,
                location: %{
                  range: %{
                    "end" => %{"character" => 23, "line" => 5},
                    "start" => %{"character" => 0, "line" => 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "config :app :key",
                kind: 20,
                location: %{
                  range: %{
                    "end" => %{"character" => 25, "line" => 6},
                    "start" => %{"character" => 0, "line" => 6}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "config :my_app [:ecto_repos]",
                kind: 20,
                location: %{
                  range: %{
                    "end" => %{"character" => 26, "line" => 8},
                    "start" => %{"character" => 0, "line" => 7}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "config :my_app MyApp.Repo",
                kind: 20,
                location: %{
                  range: %{
                    "end" => %{"character" => 0, "line" => 9},
                    "start" => %{"character" => 0, "line" => 9}
                  }
                }
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, false)
  end

  test "[nested] handles a file with a top-level module without a name" do
    uri = "file:///project/test.exs"

    text = """
    defmodule do
    def foo, do: :bar
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok, document_symbols} = DocumentSymbols.symbols(uri, parser_context, true)

    assert [
             %Protocol.DocumentSymbol{
               children: children,
               kind: 2,
               name: "MISSING_MODULE_NAME"
             }
           ] = document_symbols

    assert [
             %Protocol.DocumentSymbol{
               children: [],
               kind: 12,
               name: "def foo"
             }
           ] = children
  end

  test "[nested] handles a file with a top-level protocol module without a name" do
    uri = "file:///project/test.exs"

    text = """
    defprotocol do
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok, document_symbols} = DocumentSymbols.symbols(uri, parser_context, true)

    assert [
             %Protocol.DocumentSymbol{
               children: [],
               kind: 11,
               name: "MISSING_PROTOCOL_NAME"
             }
           ] = document_symbols
  end

  test "handles a file with compilation errors by returning an empty list" do
    uri = "file:///project/test.exs"

    text = """
    defmodule aA do)
      def hello do
        Hello.hi(
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok, []} =
             DocumentSymbols.symbols(uri, parser_context, true)
  end

  test "returns def and defp as a prefix" do
    uri = "file:///project/test.exs"

    text = """
    defmodule A do
      def hello do
        greetings()
      end

      defp greetings do
        IO.puts("Hello, world")
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    name: "def hello"
                  },
                  %Protocol.DocumentSymbol{
                    name: "defp greetings"
                  }
                ]
              }
            ]} = DocumentSymbols.symbols(uri, parser_context, true)
  end

  describe "invalid documents" do
    test "handles a module being defined" do
      uri = "file:///project.test.ex"
      text = "defmodule "

      parser_context = ParserContextBuilder.from_string(text)

      assert {:ok, []} = DocumentSymbols.symbols(uri, parser_context, true)
    end

    test "handles a protocol being defined" do
      uri = "file:///project.test.ex"
      text = "defprotocol "

      parser_context = ParserContextBuilder.from_string(text)

      assert {:ok, []} = DocumentSymbols.symbols(uri, parser_context, true)
    end

    test "handles a protocol being impolemented" do
      uri = "file:///project.test.ex"
      text = "defimpl "

      parser_context = ParserContextBuilder.from_string(text)
      
      assert {:ok, []} = DocumentSymbols.symbols(uri, parser_context, true)
    end
  end
end
