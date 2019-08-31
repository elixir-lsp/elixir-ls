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
                    range: %{
                      end: %{character: 9, line: 2},
                      start: %{character: 9, line: 2}
                    },
                    selectionRange: %{
                      end: %{character: 9, line: 2},
                      start: %{character: 9, line: 2}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_fn(arg)",
                    range: %{
                      end: %{character: 12, line: 3},
                      start: %{character: 12, line: 3}
                    },
                    selectionRange: %{
                      end: %{character: 12, line: 3},
                      start: %{character: 12, line: 3}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_private_fn(arg)",
                    range: %{
                      end: %{character: 13, line: 4},
                      start: %{character: 13, line: 4}
                    },
                    selectionRange: %{
                      end: %{character: 13, line: 4},
                      start: %{character: 13, line: 4}
                    }
                  },
                  %{
                    children: [],
                    kind: 12,
                    name: "my_macro()",
                    range: %{
                      end: %{character: 17, line: 5},
                      start: %{character: 17, line: 5}
                    },
                    selectionRange: %{
                      end: %{character: 17, line: 5},
                      start: %{character: 17, line: 5}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
                },
                selectionRange: %{
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
                }
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
                      end: %{character: 18, line: 2},
                      start: %{character: 18, line: 2}
                    },
                    selectionRange: %{
                      end: %{character: 18, line: 2},
                      start: %{character: 18, line: 2}
                    }
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: %{
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
                },
                selectionRange: %{
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
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
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
                },
                selectionRange: %{
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
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
                  end: %{character: 16, line: 4},
                  start: %{character: 16, line: 4}
                },
                selectionRange: %{
                  end: %{character: 16, line: 4},
                  start: %{character: 16, line: 4}
                }
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
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
                },
                selectionRange: %{
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
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
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
                },
                selectionRange: %{
                  end: %{character: 16, line: 1},
                  start: %{character: 16, line: 1}
                }
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end
end
