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
    Code.string_to_quoted!(src, columns: true, line: 0)
    |> extract_moduls()
  end

  # Identify and extract the module symbol, and the symbols contained within the module
  defp extract_moduls({:__block__, [], ast}) do
    ast |> Enum.map(&extract_moduls(&1)) |> List.flatten()
  end

  defp extract_moduls({:defmodule, _, _child_ast} = ast) do
    [extract_symbol("", ast)]
  end

  defp extract_moduls_aaa({:defmodule, _, _child_ast} = ast) do
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

    [%{type: :module, name: module_name, location: location, children: module_symbols}]
  end

  defp extract_moduls(_ast), do: []

  # Module Variable
  defp extract_symbol(_module_name, {:defmodule, _, _child_ast} = ast) do
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

    %{type: :module, name: module_name, location: location, children: module_symbols}
  end

  defp extract_symbol(_, {:@, _, [{:moduledoc, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:doc, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:spec, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:behaviour, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:impl, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:type, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:typedoc, _, _}]}), do: nil
  defp extract_symbol(_, {:@, _, [{:enforce_keys, _, _}]}), do: nil

  defp extract_symbol(_current_module, {:@, _, [{name, location, _}]}) do
    %{type: :constant, name: "@#{name}", location: location, children: []}
  end

  # Function
  defp extract_symbol(_current_module, {:def, _, [{_, location, _} = fn_head | _]}) do
    %{
      type: :function,
      name: Macro.to_string(fn_head),
      location: location,
      children: []
    }
  end

  # Private Function
  defp extract_symbol(_current_module, {:defp, _, [{_, location, _} = fn_head | _]}) do
    %{
      type: :function,
      name: Macro.to_string(fn_head),
      location: location,
      children: []
    }
  end

  # Macro
  defp extract_symbol(_current_module, {:defmacro, _, [{_, location, _} = fn_head | _]}) do
    %{
      type: :function,
      name: Macro.to_string(fn_head),
      location: location,
      children: []
    }
  end

  # Test
  defp extract_symbol(_current_module, {:test, location, [name | _]}) do
    %{
      type: :function,
      name: ~s(test "#{name}"),
      location: location,
      children: []
    }
  end

  # Describe
  defp extract_symbol(current_module, {:describe, location, [name | ast]}) do
    [[do: module_body]] = ast

    mod_defns =
      case module_body do
        {:__block__, [], mod_defns} -> mod_defns
        stmt -> [stmt]
      end

    module_symbols =
      mod_defns
      |> Enum.map(&extract_symbol(current_module, &1))
      |> Enum.reject(&is_nil/1)

    %{
      type: :function,
      name: ~s(describe "#{name}"),
      location: location,
      children: module_symbols
    }
  end

  defp extract_symbol(_, _), do: nil

  defp build_symbol_information(uri, info) when is_list(info),
    do: Enum.map(info, &build_symbol_information(uri, &1))

  defp build_symbol_information(uri, info) do
    %{
      name: info.name,
      kind: @symbol_enum[info.type],
      range: location_to_range(info.location),
      selectionRange: location_to_range(info.location),
      children: build_symbol_information(uri, info.children)
    }
  end

  defp location_to_range(location) do
    %{
      start: %{line: location[:line], character: location[:column] - 1},
      end: %{line: location[:line], character: location[:column] - 1}
    }
  end
end
