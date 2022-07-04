defmodule ElixirLS.LanguageServer.Providers.DocumentSymbols do
  @moduledoc """
  Document Symbols provider. Generates and returns the nested `DocumentSymbol` format.

  https://microsoft.github.io//language-server-protocol/specifications/specification-3-14/#textDocument_documentSymbol
  """

  alias ElixirLS.LanguageServer.Providers.SymbolUtils
  alias ElixirLS.LanguageServer.SourceFile
  require ElixirLS.LanguageServer.Protocol, as: Protocol

  defmodule Info do
    defstruct [:type, :name, :location, :children]
  end

  defmodule Symbols do
    @derive {Inspect, only: []}
    @keys [:module_name, :symbols, :custom_defs]
    @enforce_keys @keys
    defstruct @keys

    def as_flat_info_list(%Symbols{symbols: []}), do: []
    def as_flat_info_list(%Info{} = info), do: [info]
    def as_flat_info_list(%Symbols{symbols: symbols}) do
      symbols
      |> List.flatten()
      |> Enum.flat_map(&as_flat_info_list/1)
    end
  end

  @defs [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]

  @docs [
    :doc,
    :moduledoc,
    :typedoc
  ]

  @max_parser_errors 6

  def symbols(uri, text, hierarchical) do
    case list_symbols(text) do
      {:ok, symbols} ->
        {:ok, build_symbols(symbols, uri, text, hierarchical)}

      {:error, :compilation_error} ->
        {:error, :server_error, "[DocumentSymbols] Compilation error while parsing source file"}
    end
  end

  defp build_symbols(symbols, uri, text, hierarchical)

  defp build_symbols(symbols, uri, text, true) do
    Enum.map(symbols, &build_symbol_information_hierarchical(uri, text, &1))
  end

  defp build_symbols(symbols, uri, text, false) do
    symbols
    |> Enum.map(&build_symbol_information_flat(uri, text, &1))
    |> List.flatten()
  end

  defp list_symbols(src) do
    case ElixirSense.string_to_quoted(src, 1, @max_parser_errors, line: 1) do
      {:ok, quoted_form} -> {:ok, extract_modules(quoted_form)}
      {:error, _error} -> {:error, :compilation_error}
    end
  end

  # Identify and extract the module symbol, and the symbols contained within the module
  defp extract_modules({:__block__, [], ast}) do
    ast |> Enum.map(&extract_modules/1) |> List.flatten()
  end

  defp extract_modules({defname, _, _child_ast} = ast)
       when defname in [:defmodule, :defprotocol, :defimpl] do
    extract_symbol(ast, %Symbols{module_name: "", symbols: [], custom_defs: []})
    |> Symbols.as_flat_info_list()
  end

  defp extract_modules({:config, _, _} = ast) do
    extract_symbol(ast, %Symbols{module_name: "", symbols: [], custom_defs: []})
    |> Symbols.as_flat_info_list()
  end

  defp extract_modules(_ast), do: []

  # Modules, protocols
  defp extract_symbol({defname, location, arguments}, acc)
       when defname in [:defmodule, :defprotocol] do
    {module_name, module_body} =
      case arguments do
        # Handles `defmodule do\nend` type compile errors
        [[do: module_body]] ->
          # The LSP requires us to return a non-empty name
          case defname do
            :defmodule -> {"MISSING_MODULE_NAME", module_body}
            :defprotocol -> {"MISSING_PROTOCOL_NAME", module_body}
          end

        [module_expression, [do: module_body]] ->
          {extract_module_name(module_expression), module_body}
      end

    mod_defns =
      case module_body do
        {:__block__, [], mod_defns} -> mod_defns
        stmt -> [stmt]
      end

    module_symbols =
      mod_defns
      |> Enum.reduce(acc, &extract_symbol/2)
      |> Symbols.as_flat_info_list()

    type =
      case defname do
        :defmodule -> :module
        :defprotocol -> :interface
      end

    %{acc | symbols: [acc, %Info{type: type, name: module_name, location: location, children: module_symbols}]}
  end

  # Protocol implementations
  defp extract_symbol(
    {:defimpl, location, [protocol_expression, [for: for_expression], [do: module_body]]},
    %Symbols{module_name: module_name} = acc
       ) do
        result = extract_symbol(
      {:defmodule, location,
       [[protocol: protocol_expression, implementations: for_expression], [do: module_body]]}, acc
    )

    %{acc | symbols: [acc.symbols, result.symbols]}
  end

  # Struct and exception
  defp extract_symbol({defname, location, [properties | _]}, %Symbols{} = acc)
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

    %{acc | symbols: [acc.symbols, %Info{type: :struct, name: name, location: location, children: children} ]}
  end

  # Docs
  defp extract_symbol({:@, _, [{kind, _, _}]}, %Symbols{} = acc) when kind in @docs, do: acc

  # Types
  defp extract_symbol({:@, _, [{type_kind, location, type_expression}]}, %Symbols{} = acc)
       when type_kind in [:type, :typep, :opaque, :spec, :callback, :macrocallback] do
    type_name =
      case type_expression do
        [{:"::", _, [{_, _, _} = type_head | _]}] ->
          Macro.to_string(type_head)

        [{:when, _, [{:"::", _, [{_, _, _} = type_head, _]}, _]}] ->
          Macro.to_string(type_head)
      end
      |> String.replace("\n", "")

    type = if type_kind in [:type, :typep, :opaque], do: :class, else: :event

    %{acc | symbols: [acc.symbols, %Info{
      type: type,
      name: type_name,
      location: location,
      children: []
  }]}
  end

  # @behaviour BehaviourModule
  defp extract_symbol({:@, _, [{:behaviour, location, [behaviour_expression]}]}, %Symbols{} = acc) do
    module_name = extract_module_name(behaviour_expression)

    %{acc | symbols: [acc.symbols, %Info{type: :constant, name: "@behaviour #{module_name}", location: location, children: []}]}
  end

  # @impl true
  defp extract_symbol({:@, _, [{:impl, location, [true]}]}, %Symbols{} = acc) do
    %{acc | symbols: [acc.symbols, %Info{type: :constant, name: "@impl true", location: location, children: []}]}
  end

  # @impl BehaviourModule
  defp extract_symbol({:@, _, [{:impl, location, [impl_expression]}]}, %Symbols{} = acc) do
    module_name = extract_module_name(impl_expression)

    %{acc | symbols: [acc.symbols, %Info{type: :constant, name: "@impl #{module_name}", location: location, children: []}]}
  end

  # Other attributes
  defp extract_symbol({:@, _, [{name, location, _}]}, %Symbols{} = acc) do
    %{acc | symbols: [acc.symbols, %Info{type: :constant, name: "@#{name}", location: location, children: []}]}
  end

  # Config entry
  defp extract_symbol({:config, location, [app, config_entry | _]}, acc)
       when is_atom(app) do
    keys =
      case config_entry do
        list when is_list(list) ->
          list
          |> Enum.map(fn {key, _} -> Macro.to_string(key) end)

        key ->
          [Macro.to_string(key)]
      end

    symbols = for key <- keys do
      %Info{
        type: :key,
        name: "config :#{app} #{key}",
        location: location,
        children: []
      }
    end

    %{acc | symbols: [acc.symbols, symbols]}
  end

  # Functions and macros
  defp extract_symbol({defname, _location, _args} = node, %Symbols{} = acc) when is_atom(defname) do
    # The compiler will only let one use a macro if it was defined previously,
    # so it should already be in the symbols list

    symbols = Symbols.as_flat_info_list(acc)

    require IEx; IEx.pry()

    if defname in @defs or Enum.any?(symbols, & &1.type == :function and String.contains?(&1.name, Atom.to_string(defname))) do
      do_extract_symbol(node, %{acc | symbols: symbols})
    else
      # If the potential symbol is not currently present in the symbol list,
      # it might be a potential imported macro. We should do something better
      # here
      if defname in [:test, :setup, :setup_all, :describe, :config] do
        do_extract_symbol(node, %{acc | symbols: symbols})
      else
        acc
      end
    end
  end

   # ExUnit test
  defp do_extract_symbol({:test, location, [name | _]}, acc) do
    %{acc | symbols: [acc.symbols, %Info{
      type: :function,
      name: "test #{Macro.to_string(name)}",
      location: location,
      children: []
    }]}
  end

  # ExUnit setup and setup_all callbacks
  defp do_extract_symbol({name, location, [_name | _]}, acc)
       when name in [:setup, :setup_all] do
    %{acc | symbols: [acc.symbols, %Info{
      type: :function,
      name: "#{name}",
      location: location,
      children: []
    }]}
  end

  # ExUnit describe
  defp do_extract_symbol({:describe, location, [name | [[do: module_body]]]}, acc) do
    mod_defns =
      case module_body do
        {:__block__, [], mod_defns} -> mod_defns
        stmt -> [stmt]
      end

    module_symbols =
      mod_defns
      |> Enum.reduce(acc, &extract_symbol/2)
      |> Symbols.as_flat_info_list()


    %{acc | symbols: [acc.symbols, %Info{
      type: :function,
      name: "describe #{Macro.to_string(name)}",
      location: location,
      children: module_symbols
    }]}
  end

  # Function, macro, guard with when
  defp do_extract_symbol(
         {defname, _, [{:when, _, [{_, location, _} = fn_head, _]} | _]}, %Symbols{} = acc
       )
       when is_atom(defname) do
    name = Macro.to_string(fn_head) |> String.replace("\n", "")

    %{acc | symbols: [acc.symbols, %Info{
      type: :function,
      name: "#{defname} #{name}",
      location: location,
      children: []
    }]}
  end

  # Function, macro, delegate
  defp do_extract_symbol({defname, _, [{_, location, _} = fn_head | _]}, acc) when is_atom(defname) do
    name = Macro.to_string(fn_head) |> String.replace("\n", "")

    %{acc | symbols: [acc.symbols, %Info{
      type: :function,
      name: "#{defname} #{name}",
      location: location,
      children: []
    }]}
  end

  defp extract_symbol(_, acc), do: acc

  defp build_symbol_information_hierarchical(uri, text, info) when is_list(info),
    do: Enum.map(info, &build_symbol_information_hierarchical(uri, text, &1))

  defp build_symbol_information_hierarchical(uri, text, %Info{} = info) do
    range = location_to_range(info.location, text)

    %Protocol.DocumentSymbol{
      name: info.name,
      kind: SymbolUtils.symbol_kind_to_code(info.type),
      range: range,
      selectionRange: range,
      children: build_symbol_information_hierarchical(uri, text, info.children)
    }
  end

  defp build_symbol_information_flat(uri, text, info, parent_name \\ nil)

  defp build_symbol_information_flat(uri, text, info, parent_name) when is_list(info),
    do: Enum.map(info, &build_symbol_information_flat(uri, text, &1, parent_name))

  defp build_symbol_information_flat(uri, text, %Info{} = info, parent_name) do
    case info.children do
      [_ | _] ->
        [
          %Protocol.SymbolInformation{
            name: info.name,
            kind: SymbolUtils.symbol_kind_to_code(info.type),
            location: %{
              uri: uri,
              range: location_to_range(info.location, text)
            },
            containerName: parent_name
          }
          | Enum.map(info.children, &build_symbol_information_flat(uri, text, &1, info.name))
        ]

      _ ->
        %Protocol.SymbolInformation{
          name: info.name,
          kind: SymbolUtils.symbol_kind_to_code(info.type),
          location: %{
            uri: uri,
            range: location_to_range(info.location, text)
          },
          containerName: parent_name
        }
    end
  end

  defp location_to_range(location, text) do
    {line, character} =
      SourceFile.elixir_position_to_lsp(text, {location[:line], location[:column]})

    Protocol.range(line, character, line, character)
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
    %Info{
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
