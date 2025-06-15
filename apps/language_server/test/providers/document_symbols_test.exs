defmodule ElixirLS.LanguageServer.Providers.DocumentSymbolsTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.DocumentSymbols
  alias ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder
  import ElixirLS.LanguageServer.RangeUtils

  defp get_document_symbols(uri, text, flat) do
    results = DocumentSymbols.symbols(uri, text, flat)

    case results do
      {:ok, results} ->
        assert match?(
                 {:ok, _dumped},
                 Schematic.dump(GenLSP.Requests.TextDocumentDocumentSymbol.result(), results)
               ),
               inspect(results)

      _ ->
        :ok
    end

    results
  end

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
        def fun_multiline_args(
              foo,
              bar
            )
            when is_atom(foo),
            do: foo
        def fun_multiline_args(
              foo,
              bar
            ),
            do: bar
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@my_mod_var",
                    range: range(2, 8, 2, 37),
                    selection_range: range(2, 8, 2, 37)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn/1",
                    detail: "def",
                    range: range(3, 8, 3, 31),
                    selection_range: range(3, 12, 3, 22)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_private_fn/1",
                    detail: "defp"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "my_macro/0",
                    detail: "defmacro"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "my_private_macro/0",
                    detail: "defmacrop"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "my_guard/1",
                    detail: "defguard",
                    range: range(7, 8, 7, 47),
                    selection_range: range(7, 17, 7, 28)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "my_private_guard/1",
                    detail: "defguardp"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_delegate/1",
                    detail: "defdelegate",
                    range: range(9, 8, 9, 61),
                    selection_range: range(9, 20, 9, 37)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 14,
                    name: "my_guard/0",
                    detail: "defguard"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn_no_arg/0",
                    range: range(11, 8, 11, 33),
                    selection_range: range(11, 12, 11, 24)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn_with_guard/1"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn_with_more_blocks/1",
                    range: range(13, 8, 23, 11),
                    selection_range: range(13, 12, 13, 39)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "fun_multiple_when/1",
                    range: range(24, 8, 24, 42),
                    selection_range: range(24, 12, 24, 42)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "fun_multiple_when/1",
                    range: range(25, 8, 30, 11),
                    selection_range: range(25, 12, 25, 35)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "fun_multiple_when/1",
                    range: range(31, 8, 33, 11),
                    selection_range: range(31, 12, 31, 37)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "fun_multiline_args/2"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "fun_multiline_args/2"
                  }
                ],
                kind: 2,
                name: "MyModule",
                detail: "defmodule",
                range: range(1, 6, 45, 9),
                selection_range: range(1, 16, 1, 24)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
        def fun_multiline_args(
              foo,
              bar
            )
            when is_atom(foo),
            do: foo
        def fun_multiline_args(
              foo,
              bar
            ),
            do: bar
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: range(1, 6, 35, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@my_mod_var",
                kind: 22,
                location: %{
                  range: range(2, 8, 2, 37)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn/1",
                kind: 12,
                location: %{
                  range: range(3, 8, 3, 31)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_private_fn/1",
                kind: 12,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_macro/0",
                kind: 14,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_private_macro/0",
                kind: 14,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_guard/1",
                kind: 14,
                location: %{
                  range: range(7, 8, 7, 47)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_private_guard/1",
                kind: 14,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_delegate/1",
                kind: 12,
                location: %{
                  range: range(9, 8, 9, 61)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_guard/0",
                kind: 14,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn_no_arg/0",
                kind: 12,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn_with_guard/1",
                kind: 12,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn_with_more_blocks/1",
                kind: 12,
                location: %{
                  range: range(13, 8, 23, 11)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "fun_multiline_args/2",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "fun_multiline_args/2",
                container_name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "my_fn/0"
                      }
                    ],
                    kind: 2,
                    name: "Sub.Module",
                    range: range(2, 8, 4, 11),
                    selection_range: range(2, 18, 2, 28)
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: range(1, 6, 5, 9),
                selection_range: range(1, 16, 1, 24)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: range(1, 6, 5, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "SubModule",
                kind: 2,
                location: %{
                  range: range(2, 8, 4, 11)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "my_fn/0",
                container_name: "SubModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "some_function/0"
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: range(1, 6, 3, 9),
                selection_range: range(1, 16, 1, 24)
              },
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "some_other_function/0"
                  }
                ],
                kind: 2,
                name: "MyOtherModule",
                range: range(4, 6, 6, 9),
                selection_range: range(4, 16, 4, 29)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: range(1, 6, 3, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "some_function/0",
                kind: 12,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "MyOtherModule",
                kind: 2,
                location: %{
                  range: range(4, 6, 6, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "some_other_function/0",
                container_name: "MyOtherModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn/0"
                  }
                ],
                kind: 2,
                name: "MyModule",
                range: range(1, 6, 3, 9),
                selection_range: range(1, 6, 3, 9)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: range(1, 6, 3, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn/0",
                kind: 12,
                container_name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn/0"
                  }
                ],
                kind: 2,
                name: "unquote(var)",
                range: range(1, 6, 3, 9),
                selection_range: range(1, 16, 1, 28)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "unquote(var)",
                kind: 2,
                location: %{
                  range: range(1, 6, 3, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "my_fn/0",
                container_name: "unquote(var)"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn/0"
                  }
                ],
                kind: 2,
                name: "my_module",
                range: range(1, 6, 3, 9),
                selection_range: range(1, 6, 3, 9)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "my_module",
                kind: 2,
                location: %{
                  range: range(1, 6, 3, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn/0",
                kind: 12,
                container_name: "my_module"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "my_fn/0"
                      }
                    ],
                    kind: 2,
                    name: "__MODULE__.SubModule"
                  }
                ],
                kind: 2,
                name: "__MODULE__"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "__MODULE__",
                kind: 2
              },
              %GenLSP.Structures.SymbolInformation{
                name: "__MODULE__.SubModule",
                kind: 2,
                container_name: "__MODULE__"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn/0",
                kind: 12,
                container_name: "__MODULE__.SubModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "size/1",
                    range: range(2, 2, 2, 16),
                    selection_range: range(2, 6, 2, 16)
                  }
                ],
                kind: 11,
                name: "MyProtocol",
                detail: "defprotocol",
                range: range(0, 0, 3, 3),
                selection_range: range(0, 12, 0, 22)
              },
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "size/1",
                    range: range(6, 2, 6, 41),
                    selection_range: range(6, 6, 6, 18)
                  }
                ],
                kind: 2,
                name: "MyProtocol, for: BitString",
                detail: "defimpl",
                range: range(5, 0, 7, 3),
                selection_range: range(5, 0, 7, 3)
              },
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "size/1",
                    range: range(10, 2, 10, 36),
                    selection_range: range(10, 6, 10, 17)
                  }
                ],
                kind: 2,
                name: "MyProtocol, for: [List, MyList]",
                range: range(9, 0, 11, 3),
                selection_range: range(9, 0, 11, 3)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyProtocol",
                kind: 11,
                location: %{
                  range: range(0, 0, 3, 3)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "size/1",
                location: %{
                  range: range(2, 2, 2, 16)
                },
                container_name: "MyProtocol"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 2,
                name: "MyProtocol, for: BitString",
                location: %{
                  range: range(5, 0, 7, 3)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "size/1",
                location: %{
                  range: range(6, 2, 6, 41)
                },
                container_name: "MyProtocol, for: BitString"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 2,
                name: "MyProtocol, for: [List, MyList]",
                location: %{
                  range: range(9, 0, 11, 3)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 12,
                name: "size/1",
                location: %{
                  range: range(10, 2, 10, 36)
                },
                container_name: "MyProtocol, for: [List, MyList]"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "prop",
                        range: range(1, 2, 1, 39),
                        selection_range: range(1, 2, 1, 39)
                      },
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "prop_with_def",
                        range: range(1, 2, 1, 39),
                        selection_range: range(1, 2, 1, 39)
                      }
                    ],
                    kind: 23,
                    name: "defstruct MyModule",
                    range: range(1, 2, 1, 39),
                    selection_range: range(1, 2, 1, 39)
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %GenLSP.Structures.SymbolInformation{
                name: "defstruct MyModule",
                kind: 23,
                location: %{
                  range: range(1, 2, 1, 39)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "prop",
                kind: 7,
                location: %{
                  range: range(1, 2, 1, 39)
                },
                container_name: "defstruct MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 7,
                name: "prop_with_def",
                location: %{
                  range: range(1, 2, 1, 39)
                },
                container_name: "defstruct MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "message",
                        range: range(1, 2, 1, 25),
                        selection_range: range(1, 2, 1, 25)
                      }
                    ],
                    kind: 23,
                    name: "defexception MyError",
                    range: range(1, 2, 1, 25),
                    selection_range: range(1, 2, 1, 25)
                  }
                ],
                kind: 2,
                name: "MyError"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyError",
                kind: 2
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 23,
                name: "defexception MyError",
                location: %{
                  range: range(1, 2, 1, 25)
                },
                container_name: "MyError"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 7,
                name: "message",
                location: %{
                  range: range(1, 2, 1, 25)
                },
                container_name: "defexception MyError"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
      @type my_with_multiline_args(
              key,
              value
            ) :: [{key, value}]
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %{
                    children: [],
                    kind: 5,
                    name: "my_simple/0",
                    detail: "@type",
                    range: range(1, 2, 1, 28),
                    selection_range: range(1, 8, 1, 17)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_union/0"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_simple_private/0",
                    detail: "@typep"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_simple_opaque/0",
                    detail: "@opaque"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_with_args/2"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_with_args_when/2"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "abc/0"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@type"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 5,
                    name: "my_with_multiline_args/2"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
      @type my_with_multiline_args(
              key,
              value
            ) :: [{key, value}]
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "my_simple/0",
                location: %{
                  range: range(1, 2, 1, 28)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "my_union/0",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "my_simple_private/0",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "my_simple_opaque/0",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "my_with_args/2",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "my_with_args_when/2",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "abc/0",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 22,
                name: "@type",
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                kind: 5,
                name: "my_with_multiline_args/2",
                container_name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_callback/2",
                    detail: "@callback",
                    range: range(1, 2, 1, 52),
                    selection_range: range(1, 12, 1, 37)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback/2",
                    detail: "@macrocallback"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_callback_when/2",
                    detail: "@callback"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback_when/2",
                    detail: "@macrocallback"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_callback_no_arg/0",
                    detail: "@callback"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 24,
                    name: "my_macrocallback_no_arg/0",
                    detail: "@macrocallback"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_callback/2",
                kind: 24,
                location: %{
                  range: range(1, 2, 1, 52)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_macrocallback/2",
                kind: 24,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_callback_when/2",
                kind: 24,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_macrocallback_when/2",
                kind: 24,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_callback_no_arg/0",
                kind: 24,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_macrocallback_no_arg/0",
                kind: 24,
                container_name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "my_fn/1"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2
              },
              %GenLSP.Structures.SymbolInformation{
                name: "my_fn/1",
                kind: 12,
                container_name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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

    result = get_document_symbols(uri, parser_context, true)

    assert {:ok,
            [
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "name",
                        range: range(3, 15, 3, 55),
                        selection_range: range(3, 15, 3, 55)
                      },
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 7,
                        name: "age",
                        range: range(3, 15, 3, 55),
                        selection_range: range(3, 15, 3, 55)
                      }
                    ],
                    kind: 5,
                    name: ":user",
                    detail: "defrecord",
                    range: range(3, 8, 3, 55),
                    selection_range: range(3, 8, 3, 55)
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = result
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

    result = get_document_symbols(uri, parser_context, false)

    assert {:ok,
            [
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: range(1, 6, 4, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: ":user",
                kind: 5,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                container_name: ":user",
                kind: 7,
                location: %{
                  range: range(3, 15, 3, 55),
                  uri: "file:///project/file.ex"
                },
                name: "name"
              },
              %GenLSP.Structures.SymbolInformation{
                container_name: ":user",
                kind: 7,
                location: %{
                  range: range(3, 15, 3, 55),
                  uri: "file:///project/file.ex"
                },
                name: "age"
              }
            ]} = result
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
              %GenLSP.Structures.DocumentSymbol{
                children: [],
                kind: 2,
                name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@optional_callbacks",
                    range: range(1, 2, 1, 58),
                    selection_range: range(1, 2, 1, 58)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 11,
                    name: "@behaviour MyBehaviour"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@derive"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@enforce_keys"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@compile"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@dialyzer"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@file"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@external_resource"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@on_load"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@on_definition"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@vsn"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@after_compile"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@before_compile"
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 22,
                    name: "@fallback_to_any"
                  }
                ],
                kind: 2,
                name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModule",
                kind: 2,
                location: %{
                  range: range(0, 0, 18, 3)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@optional_callbacks",
                kind: 22,
                location: %{
                  range: range(1, 2, 1, 58)
                },
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@behaviour MyBehaviour",
                kind: 11,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@derive",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@enforce_keys",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@compile",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@dialyzer",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@file",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@external_resource",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@on_load",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@on_definition",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@vsn",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@after_compile",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@before_compile",
                kind: 22,
                container_name: "MyModule"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "@fallback_to_any",
                kind: 22,
                container_name: "MyModule"
              }
            ]} = get_document_symbols(uri, parser_context, false)
  end

  test "[nested] handles exunit tests" do
    uri = "file:///project/test.exs"
    text = ~S[
      defmodule MyModuleTest do
        use ExUnit.Case
        test "does something", do: :ok
        test "not implemented"
      end
    ]

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok,
            [
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "\"does something\"",
                    detail: "test",
                    range: range(3, 8, 3, 38),
                    selection_range: range(3, 8, 3, 38)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "\"not implemented\"",
                    detail: "test",
                    range: range(4, 8, 4, 30),
                    selection_range: range(4, 8, 4, 30)
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: range(1, 6, 4, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "\"does something\"",
                kind: 12,
                location: %{
                  range: range(3, 8, 3, 38)
                },
                container_name: "MyModuleTest"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "\"does something\"",
                        range: range(4, 10, 4, 40),
                        selection_range: range(4, 10, 4, 40)
                      }
                    ],
                    kind: 12,
                    name: "\"some description\"",
                    detail: "describe",
                    range: range(3, 8, 5, 11),
                    selection_range: range(3, 8, 5, 11)
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [
                      %GenLSP.Structures.DocumentSymbol{
                        children: [],
                        kind: 12,
                        name: "\"does\" <> \"something\"",
                        range: range(4, 10, 4, 45),
                        selection_range: range(4, 10, 4, 45)
                      }
                    ],
                    kind: 12,
                    name: describe_sigil,
                    range: range(3, 8, 5, 11),
                    selection_range: range(3, 8, 5, 11)
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = get_document_symbols(uri, parser_context, true)

    assert describe_sigil == "~S(some \"description\")"
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: range(1, 6, 6, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "\"some description\"",
                kind: 12,
                location: %{
                  range: range(3, 8, 5, 11)
                },
                container_name: "MyModuleTest"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "\"does something\"",
                kind: 12,
                location: %{
                  range: range(4, 10, 4, 40)
                },
                container_name: "\"some description\""
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: range(1, 6, 6, 9)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: describe_sigil,
                kind: 12,
                location: %{
                  range: range(3, 8, 5, 11)
                },
                container_name: "MyModuleTest"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "\"does\" <> \"something\"",
                kind: 12,
                location: %{
                  range: range(4, 10, 4, 45)
                },
                container_name: describe_sigil
              }
            ]} = get_document_symbols(uri, parser_context, false)

    assert describe_sigil == "~S(some \"description\")"
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
              %GenLSP.Structures.DocumentSymbol{
                children: [
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup",
                    range: range(2, 2, 4, 5),
                    selection_range: range(2, 2, 4, 5)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup",
                    range: range(5, 2, 5, 31),
                    selection_range: range(5, 2, 5, 31)
                  },
                  %GenLSP.Structures.DocumentSymbol{
                    children: [],
                    kind: 12,
                    name: "setup_all",
                    range: range(6, 2, 8, 5),
                    selection_range: range(6, 2, 8, 5)
                  }
                ],
                kind: 2,
                name: "MyModuleTest"
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "MyModuleTest",
                kind: 2,
                location: %{
                  range: range(0, 0, 9, 3)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "setup",
                kind: 12,
                location: %{
                  range: range(2, 2, 4, 5)
                },
                container_name: "MyModuleTest"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "setup",
                kind: 12,
                location: %{
                  range: range(5, 2, 5, 31)
                },
                container_name: "MyModuleTest"
              },
              %GenLSP.Structures.SymbolInformation{
                name: "setup_all",
                kind: 12,
                location: %{
                  range: range(6, 2, 8, 5)
                },
                container_name: "MyModuleTest"
              }
            ]} = get_document_symbols(uri, parser_context, false)
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
              %GenLSP.Structures.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :logger :console",
                range: range(1, 0, 5, 23),
                selection_range: range(1, 0, 5, 23)
              },
              %GenLSP.Structures.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :app :key",
                range: range(6, 0, 6, 25),
                selection_range: range(6, 0, 6, 25)
              },
              %GenLSP.Structures.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :my_app [:ecto_repos]",
                range: range(7, 0, 8, 26),
                selection_range: range(7, 0, 8, 26)
              },
              %GenLSP.Structures.DocumentSymbol{
                children: [],
                kind: 20,
                name: "config :my_app MyApp.Repo",
                range: range(9, 0, 11, 22),
                selection_range: range(9, 0, 11, 22)
              }
            ]} = get_document_symbols(uri, parser_context, true)
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
              %GenLSP.Structures.SymbolInformation{
                name: "config :logger :console",
                kind: 20,
                location: %{
                  range: range(1, 0, 5, 23)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "config :app :key",
                kind: 20,
                location: %{
                  range: range(6, 0, 6, 25)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "config :my_app [:ecto_repos]",
                kind: 20,
                location: %{
                  range: range(7, 0, 8, 26)
                }
              },
              %GenLSP.Structures.SymbolInformation{
                name: "config :my_app MyApp.Repo",
                kind: 20,
                location: %{
                  range: range(9, 0, 11, 22)
                }
              }
            ]} = get_document_symbols(uri, parser_context, false)
  end

  test "[nested] handles a file with a top-level module without a name" do
    uri = "file:///project/test.exs"

    text = """
    defmodule do
    def foo, do: :bar
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    assert {:ok, document_symbols} = get_document_symbols(uri, parser_context, true)

    assert [
             %GenLSP.Structures.DocumentSymbol{
               children: children,
               kind: 2,
               name: "MISSING_MODULE_NAME"
             }
           ] = document_symbols

    assert [
             %GenLSP.Structures.DocumentSymbol{
               children: [],
               kind: 12,
               name: "foo/0"
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

    assert {:ok, document_symbols} = get_document_symbols(uri, parser_context, true)

    assert [
             %GenLSP.Structures.DocumentSymbol{
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

    assert {:ok, []} = get_document_symbols(uri, parser_context, true)
  end

  describe "invalid documents" do
    test "handles a module being defined" do
      uri = "file:///project.test.ex"
      text = "defmodule "

      parser_context = ParserContextBuilder.from_string(text)

      assert {:ok, []} = get_document_symbols(uri, parser_context, true)
    end

    test "handles a protocol being defined" do
      uri = "file:///project.test.ex"
      text = "defprotocol "

      parser_context = ParserContextBuilder.from_string(text)

      assert {:ok, []} = get_document_symbols(uri, parser_context, true)
    end

    test "handles a protocol being impolemented" do
      uri = "file:///project.test.ex"
      text = "defimpl "

      parser_context = ParserContextBuilder.from_string(text)

      assert {:ok, []} = get_document_symbols(uri, parser_context, true)
    end
  end
end
