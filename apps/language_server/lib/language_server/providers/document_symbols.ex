defmodule ElixirLS.LanguageServer.Providers.DocumentSymbols do
  @moduledoc """
  Document Symbols provider. Generates and returns the nested `DocumentSymbol` format.

  https://microsoft.github.io//language-server-protocol/specifications/specification-3-14/#textDocument_documentSymbol
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

  @defs [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]

  @docs [
    :doc,
    :moduledoc,
    :typedoc
  ]

  def symbols(uri, text) do
    symbols = list_symbols(text) |> Enum.map(&build_symbol_information(uri, &1))
    {:ok, symbols}
  end

  defp list_symbols(src) do
    Code.string_to_quoted!(src, columns: true, line: 0)
    |> extract_modules()
  end

  # Identify and extract the module symbol, and the symbols contained within the module
  defp extract_modules({:__block__, [], ast}) do
    ast |> Enum.map(&extract_modules(&1)) |> List.flatten()
  end

  defp extract_modules({defname, _, _child_ast} = ast)
       when defname in [:defmodule, :defprotocol, :defimpl] do
    [extract_symbol("", ast)]
  end

  defp extract_modules({:config, _, _} = ast) do
    [extract_symbol("", ast)]
  end

  defp extract_modules(_ast), do: []

  # Modules, protocols
  defp extract_symbol(_module_name, {defname, location, [module_expression, [do: module_body]]})
       when defname in [:defmodule, :defprotocol] do
    mod_defns =
      case module_body do
        {:__block__, [], mod_defns} -> mod_defns
        stmt -> [stmt]
      end

    module_name = extract_module_name(module_expression)

    module_symbols =
      mod_defns
      |> Enum.map(&extract_symbol(module_name, &1))
      |> Enum.reject(&is_nil/1)

    type =
      case defname do
        :defmodule -> :module
        :defprotocol -> :interface
      end

    %{type: type, name: module_name, location: location, children: module_symbols}
  end

  # Protocol implementations
  defp extract_symbol(
         module_name,
         {:defimpl, location, [protocol_expression, [for: for_expression], [do: module_body]]}
       ) do
    extract_symbol(
      module_name,
      {:defmodule, location,
       [[protocol: protocol_expression, implementations: for_expression], [do: module_body]]}
    )
  end

  # Struct and exception
  defp extract_symbol(_module_name, {defname, location, [properties | _]})
       when defname in [:defstruct, :defexception] do
    name =
      case defname do
        :defstruct -> "struct"
        :defexception -> "exception"
      end

    children =
      if is_list(properties) do
        properties
        |> Enum.map(&extract_property(&1, location))
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    %{type: :struct, name: name, location: location, children: children}
  end

  # Docs
  defp extract_symbol(_, {:@, _, [{kind, _, _}]}) when kind in @docs, do: nil

  # Types
  defp extract_symbol(_current_module, {:@, _, [{type_kind, location, type_expression}]})
       when type_kind in [:type, :typep, :opaque, :spec, :callback, :macrocallback] do
    type_name =
      case type_expression do
        [{:"::", _, [{_, _, _} = type_head | _]}] ->
          Macro.to_string(type_head)

        [{:when, _, [{:"::", _, [{_, _, _} = type_head, _]}, _]}] ->
          Macro.to_string(type_head)
      end

    type = if type_kind in [:type, :typep, :opaque], do: :class, else: :event

    %{
      type: type,
      name: type_name,
      location: location,
      children: []
    }
  end

  # @behaviour BehaviourModule
  defp extract_symbol(_current_module, {:@, _, [{:behaviour, location, [behaviour_expression]}]}) do
    module_name = extract_module_name(behaviour_expression)

    %{type: :constant, name: "@behaviour #{module_name}", location: location, children: []}
  end

  # @impl true
  defp extract_symbol(_current_module, {:@, _, [{:impl, location, [true]}]}) do
    %{type: :constant, name: "@impl true", location: location, children: []}
  end

  # @impl BehaviourModule
  defp extract_symbol(_current_module, {:@, _, [{:impl, location, [impl_expression]}]}) do
    module_name = extract_module_name(impl_expression)

    %{type: :constant, name: "@impl #{module_name}", location: location, children: []}
  end

  # Other attributes
  defp extract_symbol(_current_module, {:@, _, [{name, location, _}]}) do
    %{type: :constant, name: "@#{name}", location: location, children: []}
  end

  # Function, macro, guard, delegate
  defp extract_symbol(_current_module, {defname, _, [{_, location, _} = fn_head | _]})
       when defname in @defs do
    %{
      type: :function,
      name: Macro.to_string(fn_head),
      location: location,
      children: []
    }
  end

  # ExUnit test
  defp extract_symbol(_current_module, {:test, location, [name | _]}) do
    %{
      type: :function,
      name: ~s(test "#{name}"),
      location: location,
      children: []
    }
  end

  # ExUnit setup and setup_all callbacks
  defp extract_symbol(_current_module, {name, location, [_name | _]})
       when name in [:setup, :setup_all] do
    %{
      type: :function,
      name: "#{name}",
      location: location,
      children: []
    }
  end

  # ExUnit describe
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

  # Config entry
  defp extract_symbol(_current_module, {:config, location, [app, config_entry | _]})
       when is_atom(app) do
    keys =
      case config_entry do
        list when is_list(list) ->
          list
          |> Enum.map(fn {key, _} -> Macro.to_string(key) end)

        key ->
          [Macro.to_string(key)]
      end

    for key <- keys do
      %{
        type: :key,
        name: "config :#{app} #{key}",
        location: location,
        children: []
      }
    end
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

  defp extract_module_name(protocol: protocol, implementations: implementations) do
    extract_module_name(protocol) <> ", for: " <> extract_module_name(implementations)
  end

  defp extract_module_name(list) when is_list(list) do
    list_stringified = list |> Enum.map_join(", ", &extract_module_name/1)

    "[" <> list_stringified <> "]"
  end

  defp extract_module_name({:__aliases__, location, [{:__MODULE__, _, nil} = head | tail]}) do
    extract_module_name(head) <> "." <> extract_module_name({:__aliases__, location, tail})
  end

  defp extract_module_name({:__aliases__, _location, module_names}) do
    Enum.join(module_names, ".")
  end

  defp extract_module_name({:__MODULE__, _location, nil}) do
    "__MODULE__"
  end

  defp extract_module_name(module) when is_atom(module) do
    case Atom.to_string(module) do
      "Elixir." <> elixir_module_rest -> elixir_module_rest
      erlang_module -> erlang_module
    end
  end

  defp extract_module_name(_), do: "# unknown"

  defp extract_property(property_name, location) when is_atom(property_name) do
    %{
      type: :property,
      name: "#{property_name}",
      location: location,
      children: []
    }
  end

  defp extract_property({property_name, _default}, location),
    do: extract_property(property_name, location)

  defp extract_property(_, _), do: nil
end
