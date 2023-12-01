defmodule ElixirLS.LanguageServer.Providers.DocumentSymbols do
  @moduledoc """
  Document Symbols provider. Generates and returns the nested `DocumentSymbol` format.

  https://microsoft.github.io//language-server-protocol/specifications/specification-3-14/#textDocument_documentSymbol
  """

  alias ElixirLS.LanguageServer.Providers.SymbolUtils
  alias ElixirLS.LanguageServer.SourceFile
  require ElixirLS.LanguageServer.Protocol, as: Protocol

  defmodule Info do
    defstruct [:type, :name, :location, :children, :selection_location, :symbol]
  end

  @defs [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]

  @supplementing_attributes [
    :doc,
    :moduledoc,
    :typedoc,
    :spec,
    :impl,
    :deprecated
  ]

  @max_parser_errors 6

  def symbols(uri, text, hierarchical) do
    case list_symbols(text) do
      {:ok, symbols} ->
        {:ok, build_symbols(symbols, uri, text, hierarchical)}

      {:error, :compilation_error} ->
        {:error, :server_error, "Cannot parse source file", false}
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
    case ElixirSense.string_to_quoted(src, {1, 1}, @max_parser_errors,
           line: 1,
           token_metadata: true
         ) do
      {:ok, quoted_form} -> {:ok, extract_modules(quoted_form) |> Enum.reject(&is_nil/1)}
      {:error, _error} -> {:error, :compilation_error}
    end
  end

  # Identify and extract the module symbol, and the symbols contained within the module
  defp extract_modules({:__block__, [], ast}) do
    ast |> Enum.map(&extract_modules(&1)) |> List.flatten()
  end

  # handle a bare defimpl, defprotocol or defmodule
  defp extract_modules({defname, _, nil})
       when defname in [:defmodule, :defprotocol, :defimpl] do
    []
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

  defp extract_symbol(_module_name, {defname, location, arguments})
       when defname in [:defmodule, :defprotocol] do
    module_info =
      case arguments do
        # Handles `defmodule do\nend` type compile errors
        [[do: module_body]] ->
          # The LSP requires us to return a non-empty name
          case defname do
            :defmodule -> {"MISSING_MODULE_NAME", nil, module_body}
            :defprotocol -> {"MISSING_PROTOCOL_NAME", nil, module_body}
          end

        [module_expression, [do: module_body]] ->
          module_name_location =
            case module_expression do
              {_, location, _} -> location
              _ -> nil
            end

          # TODO extract module name location from Code.Fragment.surround_context?
          # TODO better selection ranges for defimpl?
          {extract_module_name(module_expression), module_name_location, module_body}

        _ ->
          nil
      end

    if module_info do
      {module_name, module_name_location, module_body} = module_info

      mod_defns =
        case module_body do
          {:__block__, [], mod_defns} -> mod_defns
          stmt -> [stmt]
        end

      module_symbols =
        mod_defns
        |> Enum.map(&extract_symbol(module_name, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn info ->
          %{info | location: Keyword.put(info.location, :parent_location, location)}
        end)

      type =
        case defname do
          :defmodule -> :module
          :defprotocol -> :interface
        end

      %Info{
        type: type,
        name: module_name,
        location: location,
        selection_location: module_name_location,
        children: module_symbols,
        symbol: module_name
      }
    end
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
  defp extract_symbol(module_name, {defname, location, [properties | _]})
       when defname in [:defstruct, :defexception] do
    children =
      if is_list(properties) do
        properties
        |> Enum.map(&extract_property(&1, location))
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    %Info{
      type: :struct,
      name: "#{defname} #{module_name}",
      location: location,
      children: children
    }
  end

  # We skip attributes only supplementing the symbol
  defp extract_symbol(_, {:@, _, [{kind, _, _}]}) when kind in @supplementing_attributes, do: nil

  # Types
  defp extract_symbol(_current_module, {:@, location, [{type_kind, _, type_expression}]})
       when type_kind in [:type, :typep, :opaque, :callback, :macrocallback] and
              not is_nil(type_expression) do
    type_name_location =
      case type_expression do
        [{:"::", _, [{_, type_head_location, _} = type_head | _]}] ->
          {Macro.to_string(type_head), type_head_location}

        [{:when, _, [{:"::", _, [{_, type_head_location, _} = type_head, _]}, _]}] ->
          {Macro.to_string(type_head), type_head_location}

        [{_, type_head_location, _} = type_head | _] ->
          {Macro.to_string(type_head), type_head_location}

        _ ->
          nil
      end

    if type_name_location do
      {type_name, type_head_location} = type_name_location

      type_name =
        type_name
        |> String.replace("\n", "")

      type = if type_kind in [:type, :typep, :opaque], do: :class, else: :event

      %Info{
        type: type,
        name: "@#{type_kind} #{type_name}",
        location: location,
        selection_location: type_head_location,
        symbol: "#{type_name}",
        children: []
      }
    end
  end

  # @behaviour BehaviourModule
  defp extract_symbol(_current_module, {:@, location, [{:behaviour, _, [behaviour_expression]}]}) do
    module_name = extract_module_name(behaviour_expression)

    %Info{type: :interface, name: "@behaviour #{module_name}", location: location, children: []}
  end

  # Other attributes
  defp extract_symbol(_current_module, {:@, location, [{name, _, _}]}) when is_atom(name) do
    %Info{type: :constant, name: "@#{name}", location: location, children: []}
  end

  # Function, macro, guard with when
  defp extract_symbol(
         _current_module,
         {defname, location, [{:when, _, [{_, head_location, _} = fn_head, _]} | _]}
       )
       when defname in @defs do
    name = Macro.to_string(fn_head) |> String.replace("\n", "")

    %Info{
      type: :function,
      symbol: "#{name}",
      name: "#{defname} #{name}",
      location: location,
      selection_location: head_location,
      children: []
    }
  end

  # Function, macro, delegate
  defp extract_symbol(_current_module, {defname, location, [{_, head_location, _} = fn_head | _]})
       when defname in @defs do
    name = Macro.to_string(fn_head) |> String.replace("\n", "")

    %Info{
      type: :function,
      symbol: "#{name}",
      name: "#{defname} #{name}",
      location: location,
      selection_location: head_location,
      children: []
    }
  end

  defp extract_symbol(
         _current_module,
         {{:., _, [{:__aliases__, alias_location, [:Record]}, :defrecord]}, location,
          [record_name, properties]}
       ) do
    name = Macro.to_string(record_name) |> String.replace("\n", "")

    children =
      if is_list(properties) do
        properties
        |> Enum.map(&extract_property(&1, location))
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    %Info{
      type: :class,
      name: "defrecord #{name}",
      location: location |> Keyword.merge(Keyword.take(alias_location, [:line, :column])),
      children: children
    }
  end

  # ExUnit test
  defp extract_symbol(_current_module, {:test, location, [name | _]}) do
    %Info{
      type: :function,
      name: "test #{Macro.to_string(name)}",
      location: location,
      children: []
    }
  end

  # ExUnit setup and setup_all callbacks
  defp extract_symbol(_current_module, {name, location, [_name | _]})
       when name in [:setup, :setup_all] do
    %Info{
      type: :function,
      name: "#{name}",
      location: location,
      children: []
    }
  end

  # ExUnit describe
  defp extract_symbol(current_module, {:describe, location, [name | [[do: module_body]]]}) do
    mod_defns =
      case module_body do
        {:__block__, [], mod_defns} -> mod_defns
        stmt -> [stmt]
      end

    module_symbols =
      mod_defns
      |> Enum.map(&extract_symbol(current_module, &1))
      |> Enum.reject(&is_nil/1)

    %Info{
      type: :function,
      name: "describe #{Macro.to_string(name)}",
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
          string_list =
            list
            |> Enum.filter(&match?({_key, _}, &1))
            |> Enum.map_join(", ", fn {key, _} -> Macro.to_string(key) end)

          "[#{string_list}]"

        key ->
          Macro.to_string(key)
      end

    %Info{
      type: :key,
      name: "config :#{app} #{keys}",
      location: location,
      children: []
    }
  end

  defp extract_symbol(_, _), do: nil

  defp build_symbol_information_hierarchical(uri, text, info) when is_list(info),
    do: Enum.map(info, &build_symbol_information_hierarchical(uri, text, &1))

  defp build_symbol_information_hierarchical(uri, text, %Info{} = info) do
    selection_location =
      if info.selection_location && Keyword.has_key?(info.selection_location, :column) do
        info.selection_location
      else
        info.location
      end

    selection_range =
      location_to_range(selection_location, text, info.symbol)

    # range must contain selection range
    range =
      location_to_range(info.location, text, nil)
      |> maybe_extend_range(selection_range)

    %Protocol.DocumentSymbol{
      name: info.name,
      kind: SymbolUtils.symbol_kind_to_code(info.type),
      range: range,
      selectionRange: selection_range,
      children: build_symbol_information_hierarchical(uri, text, info.children)
    }
  end

  defp maybe_extend_range(
         Protocol.range(start_line, start_character, end_line, end_character),
         Protocol.range(
           selection_start_line,
           selection_start_character,
           selection_end_line,
           selection_end_character
         )
       ) do
    {extended_start_line, extended_start_character} =
      cond do
        selection_start_line < start_line ->
          {selection_start_line, selection_start_character}

        selection_start_line == start_line ->
          {selection_start_line, min(selection_start_character, start_character)}

        true ->
          {start_line, start_character}
      end

    {extended_end_line, extended_end_character} =
      cond do
        selection_end_line > end_line ->
          {selection_end_line, selection_end_character}

        selection_end_line == end_line ->
          {selection_end_line, max(selection_end_character, end_character)}

        true ->
          {end_line, end_character}
      end

    Protocol.range(
      extended_start_line,
      extended_start_character,
      extended_end_line,
      extended_end_character
    )
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
              range: location_to_range(info.location, text, nil)
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
            range: location_to_range(info.location, text, nil)
          },
          containerName: parent_name
        }
    end
  end

  defp location_to_range(location, text, symbol) do
    lines = SourceFile.lines(text)

    {start_line, start_character} =
      SourceFile.elixir_position_to_lsp(lines, {location[:line], location[:column]})

    {end_line, end_character} =
      cond do
        end_location = location[:end_of_expression] ->
          SourceFile.elixir_position_to_lsp(lines, {end_location[:line], end_location[:column]})

        end_location = location[:end] ->
          SourceFile.elixir_position_to_lsp(
            lines,
            {end_location[:line], end_location[:column] + 3}
          )

        end_location = location[:closing] ->
          # all closing tags we expect here are 1 char width
          SourceFile.elixir_position_to_lsp(
            lines,
            {end_location[:line], end_location[:column] + 1}
          )

        symbol != nil ->
          end_char = SourceFile.elixir_character_to_lsp(symbol, String.length(symbol))
          {start_line, start_character + end_char + 1}

        parent_end_line =
            location
            |> Keyword.get(:parent_location, [])
            |> Keyword.get(:end, [])
            |> Keyword.get(:line) ->
          # last expression in block does not have end_of_expression
          parent_do_line = location[:parent_location][:do][:line]

          if parent_end_line > parent_do_line do
            # take end location from parent and assume end_of_expression is last char in previous line
            end_of_expression =
              Enum.at(lines, parent_end_line - 2)
              |> String.length()

            SourceFile.elixir_position_to_lsp(
              lines,
              {parent_end_line - 1, end_of_expression + 1}
            )
          else
            # take end location from parent and assume end_of_expression is last char before final ; trimmed
            line = Enum.at(lines, parent_end_line - 1)
            parent_end_column = location[:parent_location][:end][:column]

            end_of_expression =
              line
              |> String.slice(0..(parent_end_column - 2))
              |> String.trim_trailing()
              |> String.replace_trailing(";", "")
              |> String.length()

            SourceFile.elixir_position_to_lsp(
              lines,
              {parent_end_line, end_of_expression + 1}
            )
          end

        true ->
          {start_line, start_character}
      end

    Protocol.range(start_line, start_character, end_line, end_character)
  end

  defp extract_module_name(protocol: protocol, implementations: implementations) do
    extract_module_name(protocol) <> ", for: " <> extract_module_name(implementations)
  end

  defp extract_module_name(list) when is_list(list) do
    list_stringified = list |> Enum.map_join(", ", &extract_module_name/1)

    "[" <> list_stringified <> "]"
  end

  defp extract_module_name({:__aliases__, location, [head | tail]}) when not is_atom(head) do
    extract_module_name(head) <> "." <> extract_module_name({:__aliases__, location, tail})
  end

  defp extract_module_name({:__aliases__, _location, module_names}) do
    if Enum.all?(module_names, &is_atom/1) do
      Enum.join(module_names, ".")
    else
      "# unknown"
    end
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
