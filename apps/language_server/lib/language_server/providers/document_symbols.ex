defmodule ElixirLS.LanguageServer.Providers.DocumentSymbols do
  @moduledoc """
  Document Symbols provider
  """
  @symbol_enum %{
    file: 1,
    module: 2,
    namespace: 3,
    package: 4,
    class: 5,
    method: 6,
    property: 7,
    field: 8,
    constructor: 9,
    enum: 10,
    interface: 11,
    function: 12,
    variable: 13,
    constant: 14,
    string: 15,
    number: 16,
    boolean: 17,
    array: 18,
    object: 19,
    key: 20,
    null: 21,
    enum_member: 22,
    struct: 23,
    event: 24,
    operator: 25,
    type_parameter: 26
  }

  def symbols(uri, text) do
    symbols = list_symbols(text) |> Enum.map(&build_symbol_information(uri, &1))
    {:ok, symbols}
  end

  defp list_symbols(src) do
    {_ast, symbol_list} =
      Code.string_to_quoted!(src, columns: true, line: 0)
      |> Macro.prewalk([], fn ast, symbols ->
        {ast, extract_module(ast) ++ symbols}
      end)

    symbol_list
  end

  # Identify and extract the module symbol, and the symbols contained within the module
  defp extract_module({:defmodule, _, _child_ast} = ast) do
    {_, _, [{:__aliases__, location, module_name}, [do: module_body]]} = ast

    mod_defns =
      case module_body do
        {:__block__, [], mod_defns} -> mod_defns
        stmt -> [stmt]
      end

    module_name = Enum.join(module_name, ".")

    module_symbols =
      mod_defns
      |> Enum.map(&extract_symbol(module_name, &1))
      |> Enum.reject(&is_nil/1)

    [%{type: :module, name: module_name, location: location, container: nil}] ++ module_symbols
  end

  defp extract_module(_ast), do: []

  # Module Variable
  defp extract_symbol(_, {:@, _, [{:moduledoc, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:doc, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:spec, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:behaviour, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:impl, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:type, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:typedoc, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:enforce_keys, _, _}]}), do: nil

  defp extract_symbol(current_module, {:@, _, [{name, location, _}]}) do
    %{type: :constant, name: "@#{name}", location: location, container: current_module}
  end

  # Function
  defp extract_symbol(current_module, {:def, _, [{_, location, _} = fn_head | _]}) do
    %{
      type: :function,
      name: Macro.to_string(fn_head),
      location: location,
      container: current_module
    }
  end

  # Private Function
  defp extract_symbol(current_module, {:defp, _, [{_, location, _} = fn_head | _]}) do
    %{
      type: :function,
      name: Macro.to_string(fn_head),
      location: location,
      container: current_module
    }
  end

  # Macro
  defp extract_symbol(current_module, {:defmacro, _, [{_, location, _} = fn_head | _]}) do
    %{
      type: :function,
      name: Macro.to_string(fn_head),
      location: location,
      container: current_module
    }
  end

  # Test
  defp extract_symbol(current_module, {:test, location, [name | _]}) do
    %{
      type: :function,
      name: ~s(test "#{name}"),
      location: location,
      container: current_module
    }
  end

  defp extract_symbol(_, _), do: nil

  defp build_symbol_information(uri, info) do
    %{
      name: info.name,
      kind: @symbol_enum[info.type],
      containerName: info.container,
      location: %{
        uri: uri,
        range: %{
          start: %{line: info.location[:line], character: info.location[:column] - 1},
          end: %{line: info.location[:line], character: info.location[:column] - 1}
        }
      }
    }
  end
end
