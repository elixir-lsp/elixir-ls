defmodule ElixirLS.LanguageServer.Providers.DocumentSymbolsTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.DocumentSymbols
  alias ElixirLS.LanguageServer.Protocol

  test "returns hierarchical symbol information" do
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@my_mod_var",
                    range: %{end: %{character: 9, line: 2}, start: %{character: 9, line: 2}},
                    selectionRange: %{
                      end: %{character: 9, line: 2},
                      start: %{character: 9, line: 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn(arg)",
                    range: %{end: %{character: 12, line: 3}, start: %{character: 12, line: 3}},
                    selectionRange: %{
                      end: %{character: 12, line: 3},
                      start: %{character: 12, line: 3}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defp my_private_fn(arg)",
                    range: %{end: %{character: 13, line: 4}, start: %{character: 13, line: 4}},
                    selectionRange: %{
                      end: %{character: 13, line: 4},
                      start: %{character: 13, line: 4}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defmacro my_macro()",
                    range: %{end: %{character: 17, line: 5}, start: %{character: 17, line: 5}},
                    selectionRange: %{
                      end: %{character: 17, line: 5},
                      start: %{character: 17, line: 5}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defmacrop my_private_macro()",
                    range: %{end: %{character: 18, line: 6}, start: %{character: 18, line: 6}},
                    selectionRange: %{
                      end: %{character: 18, line: 6},
                      start: %{character: 18, line: 6}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defguard my_guard(a) when is_integer(a)",
                    range: %{end: %{character: 29, line: 7}, start: %{character: 29, line: 7}},
                    selectionRange: %{
                      end: %{character: 29, line: 7},
                      start: %{character: 29, line: 7}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defguardp my_private_guard(a) when is_integer(a)",
                    range: %{end: %{character: 38, line: 8}, start: %{character: 38, line: 8}},
                    selectionRange: %{
                      end: %{character: 38, line: 8},
                      start: %{character: 38, line: 8}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defdelegate my_delegate(list)",
                    range: %{end: %{character: 20, line: 9}, start: %{character: 20, line: 9}},
                    selectionRange: %{
                      end: %{character: 20, line: 9},
                      start: %{character: 20, line: 9}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "defguard my_guard when 1 == 1",
                    range: %{end: %{character: 26, line: 10}, start: %{character: 26, line: 10}},
                    selectionRange: %{
                      end: %{character: 26, line: 10},
                      start: %{character: 26, line: 10}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn_no_arg",
                    range: %{end: %{character: 12, line: 11}, start: %{character: 12, line: 11}},
                    selectionRange: %{
                      end: %{character: 12, line: 11},
                      start: %{character: 12, line: 11}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn_with_guard(arg) when is_integer(arg)",
                    range: %{end: %{character: 34, line: 12}, start: %{character: 34, line: 12}},
                    selectionRange: %{
                      end: %{character: 34, line: 12},
                      start: %{character: 34, line: 12}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn_with_more_blocks(arg)",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "returns flat symbol information" do
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
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "@my_mod_var",
                kind: 14,
                location: %{
                  range: %{end: %{character: 9, line: 2}, start: %{character: 9, line: 2}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn(arg)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 12, line: 3}, start: %{character: 12, line: 3}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defp my_private_fn(arg)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 13, line: 4}, start: %{character: 13, line: 4}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defmacro my_macro()",
                kind: 12,
                location: %{
                  range: %{end: %{character: 17, line: 5}, start: %{character: 17, line: 5}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defmacrop my_private_macro()",
                kind: 12,
                location: %{
                  range: %{end: %{character: 18, line: 6}, start: %{character: 18, line: 6}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defguard my_guard(a) when is_integer(a)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 29, line: 7}, start: %{character: 29, line: 7}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defguardp my_private_guard(a) when is_integer(a)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 38, line: 8}, start: %{character: 38, line: 8}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defdelegate my_delegate(list)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 20, line: 9}, start: %{character: 20, line: 9}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "defguard my_guard when 1 == 1",
                kind: 12,
                location: %{
                  range: %{end: %{character: 26, line: 10}, start: %{character: 26, line: 10}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn_no_arg",
                kind: 12,
                location: %{
                  range: %{end: %{character: 12, line: 11}, start: %{character: 12, line: 11}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn_with_guard(arg) when is_integer(arg)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 34, line: 12}, start: %{character: 34, line: 12}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn_with_more_blocks(arg)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 12, line: 13}, start: %{character: 12, line: 13}}
                },
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles nested module definitions" do
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "def my_fn()",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles nested module definitions" do
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
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{
                    end: %{character: 6, line: 1},
                    start: %{character: 6, line: 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "SubModule",
                kind: 2,
                location: %{
                  range: %{
                    end: %{character: 8, line: 2},
                    start: %{character: 8, line: 2}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def my_fn()",
                location: %{
                  range: %{
                    end: %{character: 14, line: 3},
                    start: %{character: 14, line: 3}
                  }
                },
                containerName: "SubModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles multiple module definitions" do
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def some_function()",
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def some_other_function()",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles multiple module definitions" do
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
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{
                    end: %{character: 6, line: 1},
                    start: %{character: 6, line: 1}
                  }
                }
              },
              %Protocol.SymbolInformation{
                name: "def some_function()",
                kind: 12,
                location: %{
                  range: %{
                    end: %{character: 12, line: 2},
                    start: %{character: 12, line: 2}
                  }
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "MyOtherModule",
                kind: 2,
                location: %{
                  range: %{
                    end: %{character: 6, line: 4},
                    start: %{character: 6, line: 4}
                  }
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def some_other_function()",
                location: %{
                  range: %{
                    end: %{character: 12, line: 5},
                    start: %{character: 12, line: 5}
                  }
                },
                containerName: "MyOtherModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles elixir atom module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule :'Elixir.MyModule' do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn()",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles elixir atom module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule :'Elixir.MyModule' do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "def my_fn()",
                kind: 12,
                location: %{
                  range: %{end: %{character: 12, line: 2}, start: %{character: 12, line: 2}}
                },
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles unquoted module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule unquote(var) do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn()",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles unquoted module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule unquote(var) do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "# unknown",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def my_fn()",
                location: %{
                  range: %{end: %{character: 12, line: 2}, start: %{character: 12, line: 2}}
                },
                containerName: "# unknown"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles erlang atom module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule :my_module do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn()",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles erlang atom module definitions" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule :my_module do
        def my_fn(), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "my_module",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "def my_fn()",
                kind: 12,
                location: %{
                  range: %{end: %{character: 12, line: 2}, start: %{character: 12, line: 2}}
                },
                containerName: "my_module"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles nested module definitions with __MODULE__" do
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "def my_fn()",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles nested module definitions with __MODULE__" do
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
              %Protocol.SymbolInformation{
                name: "__MODULE__",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "__MODULE__.SubModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 8, line: 2}, start: %{character: 8, line: 2}}
                },
                containerName: "__MODULE__"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn()",
                kind: 12,
                location: %{
                  range: %{end: %{character: 14, line: 3}, start: %{character: 14, line: 3}}
                },
                containerName: "__MODULE__.SubModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles protocols and implementations" do
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def size(data)",
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def size(binary)",
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def size(param)",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles protocols and implementations" do
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
              %Protocol.SymbolInformation{
                name: "MyProtocol",
                kind: 11,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def size(data)",
                location: %{
                  range: %{end: %{character: 6, line: 2}, start: %{character: 6, line: 2}}
                },
                containerName: "MyProtocol"
              },
              %Protocol.SymbolInformation{
                kind: 2,
                name: "MyProtocol, for: BitString",
                location: %{
                  range: %{end: %{character: 0, line: 5}, start: %{character: 0, line: 5}}
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def size(binary)",
                location: %{
                  range: %{end: %{character: 6, line: 6}, start: %{character: 6, line: 6}}
                },
                containerName: "MyProtocol, for: BitString"
              },
              %Protocol.SymbolInformation{
                kind: 2,
                name: "MyProtocol, for: [List, MyList]",
                location: %{
                  range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 9}}
                }
              },
              %Protocol.SymbolInformation{
                kind: 12,
                name: "def size(param)",
                location: %{
                  range: %{end: %{character: 6, line: 10}, start: %{character: 6, line: 10}}
                },
                containerName: "MyProtocol, for: [List, MyList]"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles module definitions with struct" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      defstruct [:prop, prop_with_def: nil]
    end
    """

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
                        range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}},
                        selectionRange: %{
                          end: %{character: 2, line: 1},
                          start: %{character: 2, line: 1}
                        }
                      },
                      %Protocol.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "prop_with_def",
                        range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}},
                        selectionRange: %{
                          end: %{character: 2, line: 1},
                          start: %{character: 2, line: 1}
                        }
                      }
                    ],
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles module definitions with struct" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      defstruct [:prop, prop_with_def: nil]
    end
    """

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              },
              %Protocol.SymbolInformation{
                name: "struct",
                kind: 23,
                location: %{
                  range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "prop",
                kind: 7,
                location: %{
                  range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}}
                },
                containerName: "struct"
              },
              %Protocol.SymbolInformation{
                kind: 7,
                name: "prop_with_def",
                location: %{
                  range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}}
                },
                containerName: "struct"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles module definitions with exception" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyError do
      defexception [:message]
    end
    """

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
                        range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}},
                        selectionRange: %{
                          end: %{character: 2, line: 1},
                          start: %{character: 2, line: 1}
                        }
                      }
                    ],
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles module definitions with exception" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyError do
      defexception [:message]
    end
    """

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyError",
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              },
              %Protocol.SymbolInformation{
                kind: 23,
                name: "exception",
                location: %{
                  range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}}
                },
                containerName: "MyError"
              },
              %Protocol.SymbolInformation{
                kind: 7,
                name: "message",
                location: %{
                  range: %{end: %{character: 2, line: 1}, start: %{character: 2, line: 1}}
                },
                containerName: "exception"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles module definitions with typespecs" do
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
              %Protocol.DocumentSymbol{
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
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_union",
                    range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}},
                    selectionRange: %{
                      end: %{character: 3, line: 2},
                      start: %{character: 3, line: 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_simple_private",
                    range: %{end: %{character: 3, line: 3}, start: %{character: 3, line: 3}},
                    selectionRange: %{
                      end: %{character: 3, line: 3},
                      start: %{character: 3, line: 3}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_simple_opaque",
                    range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}},
                    selectionRange: %{
                      end: %{character: 3, line: 4},
                      start: %{character: 3, line: 4}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_with_args(key, value)",
                    range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}},
                    selectionRange: %{
                      end: %{character: 3, line: 5},
                      start: %{character: 3, line: 5}
                    }
                  },
                  %Protocol.DocumentSymbol{
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles module definitions with typespecs" do
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
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "my_simple",
                location: %{
                  range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "my_union",
                location: %{
                  range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "my_simple_private",
                location: %{
                  range: %{end: %{character: 3, line: 3}, start: %{character: 3, line: 3}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "my_simple_opaque",
                location: %{
                  range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "my_with_args(key, value)",
                location: %{
                  range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                kind: 5,
                name: "my_with_args_when(key, value)",
                location: %{
                  range: %{end: %{character: 3, line: 6}, start: %{character: 3, line: 6}}
                },
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles module definitions with callbacks" do
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_callback(type1, type2)",
                    range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}},
                    selectionRange: %{
                      end: %{character: 3, line: 1},
                      start: %{character: 3, line: 1}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback(type1, type2)",
                    range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}},
                    selectionRange: %{
                      end: %{character: 3, line: 2},
                      start: %{character: 3, line: 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_callback_when(type1, type2)",
                    range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}},
                    selectionRange: %{
                      end: %{character: 3, line: 4},
                      start: %{character: 3, line: 4}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback_when(type1, type2)",
                    range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}},
                    selectionRange: %{
                      end: %{character: 3, line: 5},
                      start: %{character: 3, line: 5}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_callback_no_arg()",
                    range: %{end: %{character: 3, line: 7}, start: %{character: 3, line: 7}},
                    selectionRange: %{
                      end: %{character: 3, line: 7},
                      start: %{character: 3, line: 7}
                    }
                  },
                  %Protocol.DocumentSymbol{
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles module definitions with callbacks" do
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
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              },
              %Protocol.SymbolInformation{
                name: "my_callback(type1, type2)",
                kind: 24,
                location: %{
                  range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "my_macrocallback(type1, type2)",
                kind: 24,
                location: %{
                  range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "my_callback_when(type1, type2)",
                kind: 24,
                location: %{
                  range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "my_macrocallback_when(type1, type2)",
                kind: 24,
                location: %{
                  range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "my_callback_no_arg()",
                kind: 24,
                location: %{
                  range: %{end: %{character: 3, line: 7}, start: %{character: 3, line: 7}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "my_macrocallback_no_arg()",
                kind: 24,
                location: %{
                  range: %{end: %{character: 3, line: 8}, start: %{character: 3, line: 8}}
                },
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles funs with specs" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule MyModule do
        @spec my_fn(integer) :: atom
        def my_fn(a), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_fn(integer)",
                    range: %{end: %{character: 9, line: 2}, start: %{character: 9, line: 2}},
                    selectionRange: %{
                      end: %{character: 9, line: 2},
                      start: %{character: 9, line: 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "def my_fn(a)",
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles funs with specs" do
    uri = "file://project/file.ex"
    text = ~S[
      defmodule MyModule do
        @spec my_fn(integer) :: atom
        def my_fn(a), do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "my_fn(integer)",
                kind: 24,
                location: %{
                  range: %{end: %{character: 9, line: 2}, start: %{character: 9, line: 2}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "def my_fn(a)",
                kind: 12,
                location: %{
                  range: %{end: %{character: 12, line: 3}, start: %{character: 12, line: 3}}
                },
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] skips docs attributes" do
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
              %Protocol.DocumentSymbol{
                children: [],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] skips docs attributes" do
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
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles various builtin attributes" do
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
      @impl MyBehaviour
    end
    """

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@optional_callbacks",
                    range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}},
                    selectionRange: %{
                      end: %{character: 3, line: 1},
                      start: %{character: 3, line: 1}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@behaviour MyBehaviour",
                    range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}},
                    selectionRange: %{
                      end: %{character: 3, line: 2},
                      start: %{character: 3, line: 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@impl true",
                    range: %{end: %{character: 3, line: 3}, start: %{character: 3, line: 3}},
                    selectionRange: %{
                      end: %{character: 3, line: 3},
                      start: %{character: 3, line: 3}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@derive",
                    range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}},
                    selectionRange: %{
                      end: %{character: 3, line: 4},
                      start: %{character: 3, line: 4}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@enforce_keys",
                    range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}},
                    selectionRange: %{
                      end: %{character: 3, line: 5},
                      start: %{character: 3, line: 5}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@compile",
                    range: %{end: %{character: 3, line: 6}, start: %{character: 3, line: 6}},
                    selectionRange: %{
                      end: %{character: 3, line: 6},
                      start: %{character: 3, line: 6}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@deprecated",
                    range: %{end: %{character: 3, line: 7}, start: %{character: 3, line: 7}},
                    selectionRange: %{
                      end: %{character: 3, line: 7},
                      start: %{character: 3, line: 7}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@dialyzer",
                    range: %{end: %{character: 3, line: 8}, start: %{character: 3, line: 8}},
                    selectionRange: %{
                      end: %{character: 3, line: 8},
                      start: %{character: 3, line: 8}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@file",
                    range: %{end: %{character: 3, line: 9}, start: %{character: 3, line: 9}},
                    selectionRange: %{
                      end: %{character: 3, line: 9},
                      start: %{character: 3, line: 9}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@external_resource",
                    range: %{end: %{character: 3, line: 10}, start: %{character: 3, line: 10}},
                    selectionRange: %{
                      end: %{character: 3, line: 10},
                      start: %{character: 3, line: 10}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@on_load",
                    range: %{end: %{character: 3, line: 11}, start: %{character: 3, line: 11}},
                    selectionRange: %{
                      end: %{character: 3, line: 11},
                      start: %{character: 3, line: 11}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@on_definition",
                    range: %{end: %{character: 3, line: 12}, start: %{character: 3, line: 12}},
                    selectionRange: %{
                      end: %{character: 3, line: 12},
                      start: %{character: 3, line: 12}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@vsn",
                    range: %{end: %{character: 3, line: 13}, start: %{character: 3, line: 13}},
                    selectionRange: %{
                      end: %{character: 3, line: 13},
                      start: %{character: 3, line: 13}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@after_compile",
                    range: %{end: %{character: 3, line: 14}, start: %{character: 3, line: 14}},
                    selectionRange: %{
                      end: %{character: 3, line: 14},
                      start: %{character: 3, line: 14}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@before_compile",
                    range: %{end: %{character: 3, line: 15}, start: %{character: 3, line: 15}},
                    selectionRange: %{
                      end: %{character: 3, line: 15},
                      start: %{character: 3, line: 15}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@fallback_to_any",
                    range: %{end: %{character: 3, line: 16}, start: %{character: 3, line: 16}},
                    selectionRange: %{
                      end: %{character: 3, line: 16},
                      start: %{character: 3, line: 16}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "@impl MyBehaviour",
                    range: %{end: %{character: 3, line: 17}, start: %{character: 3, line: 17}},
                    selectionRange: %{
                      end: %{character: 3, line: 17},
                      start: %{character: 3, line: 17}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles various builtin attributes" do
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
      @impl MyBehaviour
    end
    """

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              },
              %Protocol.SymbolInformation{
                name: "@optional_callbacks",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 1}, start: %{character: 3, line: 1}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@behaviour MyBehaviour",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 2}, start: %{character: 3, line: 2}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@impl true",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 3}, start: %{character: 3, line: 3}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@derive",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 4}, start: %{character: 3, line: 4}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@enforce_keys",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 5}, start: %{character: 3, line: 5}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@compile",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 6}, start: %{character: 3, line: 6}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@deprecated",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 7}, start: %{character: 3, line: 7}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@dialyzer",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 8}, start: %{character: 3, line: 8}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@file",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 9}, start: %{character: 3, line: 9}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@external_resource",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 10}, start: %{character: 3, line: 10}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@on_load",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 11}, start: %{character: 3, line: 11}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@on_definition",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 12}, start: %{character: 3, line: 12}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@vsn",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 13}, start: %{character: 3, line: 13}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@after_compile",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 14}, start: %{character: 3, line: 14}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@before_compile",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 15}, start: %{character: 3, line: 15}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@fallback_to_any",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 16}, start: %{character: 3, line: 16}}
                },
                containerName: "MyModule"
              },
              %Protocol.SymbolInformation{
                name: "@impl MyBehaviour",
                kind: 14,
                location: %{
                  range: %{end: %{character: 3, line: 17}, start: %{character: 3, line: 17}}
                },
                containerName: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles exunit tests" do
    uri = "file://project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        test "does something", do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles exunit tests" do
    uri = "file://project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        test "does something", do: :ok
      end
    ]

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "test \"does something\"",
                kind: 12,
                location: %{
                  range: %{end: %{character: 8, line: 3}, start: %{character: 8, line: 3}}
                },
                containerName: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles exunit descibe tests" do
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
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [
                      %Protocol.DocumentSymbol{
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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles exunit descibe tests" do
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
              %Protocol.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: %{end: %{character: 6, line: 1}, start: %{character: 6, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "describe \"some descripton\"",
                kind: 12,
                location: %{
                  range: %{end: %{character: 8, line: 3}, start: %{character: 8, line: 3}}
                },
                containerName: "MyModuleTest"
              },
              %Protocol.SymbolInformation{
                name: "test \"does something\"",
                kind: 12,
                location: %{
                  range: %{end: %{character: 10, line: 4}, start: %{character: 10, line: 4}}
                },
                containerName: "describe \"some descripton\""
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles exunit callbacks" do
    uri = "file://project/test.exs"

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

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup",
                    range: %{end: %{character: 2, line: 2}, start: %{character: 2, line: 2}},
                    selectionRange: %{
                      end: %{character: 2, line: 2},
                      start: %{character: 2, line: 2}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup",
                    range: %{end: %{character: 2, line: 5}, start: %{character: 2, line: 5}},
                    selectionRange: %{
                      end: %{character: 2, line: 5},
                      start: %{character: 2, line: 5}
                    }
                  },
                  %Protocol.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup_all",
                    range: %{end: %{character: 2, line: 6}, start: %{character: 2, line: 6}},
                    selectionRange: %{
                      end: %{character: 2, line: 6},
                      start: %{character: 2, line: 6}
                    }
                  }
                ],
                kind: 2,
                name: "MyModuleTest",
                range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}},
                selectionRange: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
              }
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles exunit callbacks" do
    uri = "file://project/test.exs"

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

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 0}, start: %{character: 0, line: 0}}
                }
              },
              %Protocol.SymbolInformation{
                name: "setup",
                kind: 12,
                location: %{
                  range: %{end: %{character: 2, line: 2}, start: %{character: 2, line: 2}}
                },
                containerName: "MyModuleTest"
              },
              %Protocol.SymbolInformation{
                name: "setup",
                kind: 12,
                location: %{
                  range: %{end: %{character: 2, line: 5}, start: %{character: 2, line: 5}}
                },
                containerName: "MyModuleTest"
              },
              %Protocol.SymbolInformation{
                name: "setup_all",
                kind: 12,
                location: %{
                  range: %{end: %{character: 2, line: 6}, start: %{character: 2, line: 6}}
                },
                containerName: "MyModuleTest"
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles config" do
    uri = "file://project/test.exs"

    text = """
    use Mix.Config
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

    assert {:ok,
            [
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :logger :console",
                range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 1}},
                selectionRange: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 1}}
              },
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :app :key",
                range: %{end: %{character: 0, line: 6}, start: %{character: 0, line: 6}},
                selectionRange: %{end: %{character: 0, line: 6}, start: %{character: 0, line: 6}}
              },
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :my_app :ecto_repos",
                range: %{end: %{character: 0, line: 7}, start: %{character: 0, line: 7}},
                selectionRange: %{end: %{character: 0, line: 7}, start: %{character: 0, line: 7}}
              },
              %Protocol.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :my_app MyApp.Repo",
                range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 9}},
                selectionRange: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 9}}
              }
            ]} = DocumentSymbols.symbols(uri, text, true)
  end

  test "[flat] handles config" do
    uri = "file://project/test.exs"

    text = """
    use Mix.Config
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

    assert {:ok,
            [
              %Protocol.SymbolInformation{
                name: "config :logger :console",
                kind: 20,
                location: %{
                  range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 1}}
                }
              },
              %Protocol.SymbolInformation{
                name: "config :app :key",
                kind: 20,
                location: %{
                  range: %{end: %{character: 0, line: 6}, start: %{character: 0, line: 6}}
                }
              },
              %Protocol.SymbolInformation{
                name: "config :my_app :ecto_repos",
                kind: 20,
                location: %{
                  range: %{end: %{character: 0, line: 7}, start: %{character: 0, line: 7}}
                }
              },
              %Protocol.SymbolInformation{
                name: "config :my_app MyApp.Repo",
                kind: 20,
                location: %{
                  range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 9}}
                }
              }
            ]} = DocumentSymbols.symbols(uri, text, false)
  end

  test "[nested] handles a file with a top-level module without a name" do
    uri = "file://project/test.exs"

    text = """
    defmodule do
    def foo, do: :bar
    end
    """

    assert {:ok, document_symbols} = DocumentSymbols.symbols(uri, text, true)

    assert [
             %Protocol.DocumentSymbol{
               children: children,
               kind: 2,
               name: "MISSING_MODULE_NAME",
               range: %{
                 start: %{line: 0, character: 0},
                 end: %{line: 0, character: 0}
               },
               selectionRange: %{
                 start: %{line: 0, character: 0},
                 end: %{line: 0, character: 0}
               }
             }
           ] = document_symbols

    assert children == [
             %Protocol.DocumentSymbol{
               children: [],
               kind: 12,
               name: "def foo",
               range: %{
                 start: %{character: 4, line: 1},
                 end: %{character: 4, line: 1}
               },
               selectionRange: %{
                 start: %{character: 4, line: 1},
                 end: %{character: 4, line: 1}
               }
             }
           ]
  end

  test "[nested] handles a file with a top-level protocol module without a name" do
    uri = "file://project/test.exs"

    text = """
    defprotocol do
    end
    """

    assert {:ok, document_symbols} = DocumentSymbols.symbols(uri, text, true)

    assert document_symbols == [
             %Protocol.DocumentSymbol{
               children: [],
               kind: 11,
               name: "MISSING_PROTOCOL_NAME",
               range: %{
                 start: %{line: 0, character: 0},
                 end: %{line: 0, character: 0}
               },
               selectionRange: %{
                 start: %{line: 0, character: 0},
                 end: %{line: 0, character: 0}
               }
             }
           ]
  end

  test "handles a file with compilation errors by returning an empty list" do
    uri = "file://project/test.exs"

    text = """
    defmodule A do
      def hello do
        Hello.hi(
      end
    end
    """

    assert {:error, :server_error, message} = DocumentSymbols.symbols(uri, text, true)
    assert String.contains?(message, "Compilation error")
  end

  test "returns def and defp as a prefix" do
    uri = "file://project/test.exs"

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
            ]} = DocumentSymbols.symbols(uri, text, true)
  end
end
