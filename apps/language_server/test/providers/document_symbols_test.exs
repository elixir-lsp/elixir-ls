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
                containerName: nil,
                kind: 2,
                location: %{
                  range: %{
                    end: %{character: 16, line: 1},
                    start: %{character: 16, line: 1}
                  },
                  uri: ^uri
                },
                name: "MyModule"
              },
              %{
                containerName: "MyModule",
                kind: 14,
                location: %{
                  range: %{
                    end: %{character: 9, line: 2},
                    start: %{character: 9, line: 2}
                  },
                  uri: ^uri
                },
                name: "@my_mod_var"
              },
              %{
                containerName: "MyModule",
                kind: 12,
                location: %{
                  range: %{
                    end: %{character: 12, line: 3},
                    start: %{character: 12, line: 3}
                  },
                  uri: ^uri
                },
                name: "my_fn(arg)"
              },
              %{
                containerName: "MyModule",
                kind: 12,
                location: %{
                  range: %{
                    end: %{character: 13, line: 4},
                    start: %{character: 13, line: 4}
                  },
                  uri: ^uri
                },
                name: "my_private_fn(arg)"
              },
              %{
                containerName: "MyModule",
                kind: 12,
                location: %{
                  range: %{
                    end: %{character: 17, line: 5},
                    start: %{character: 17, line: 5}
                  },
                  uri: ^uri
                },
                name: "my_macro()"
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
                containerName: nil,
                kind: 2,
                location: %{
                  range: %{
                    end: %{character: 18, line: 2},
                    start: %{character: 18, line: 2}
                  },
                  uri: "file://project/file.ex"
                },
                name: "SubModule"
              },
              %{
                containerName: "SubModule",
                kind: 12,
                location: %{
                  range: %{
                    end: %{character: 14, line: 3},
                    start: %{character: 14, line: 3}
                  },
                  uri: ^uri
                },
                name: "my_fn()"
              },
              %{
                containerName: nil,
                kind: 2,
                location: %{
                  range: %{
                    end: %{character: 16, line: 1},
                    start: %{character: 16, line: 1}
                  },
                  uri: ^uri
                },
                name: "MyModule"
              }
            ]} = DocumentSymbols.symbols(uri, text)
  end
end
