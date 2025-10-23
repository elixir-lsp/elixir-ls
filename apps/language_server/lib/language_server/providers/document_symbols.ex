defmodule ElixirLS.LanguageServer.Providers.DocumentSymbols do
  @moduledoc """
  Document Symbols provider. Generates and returns the nested `DocumentSymbol` format.

  https://microsoft.github.io//language-server-protocol/specifications/specification-3-14/#textDocument_documentSymbol
  """

  alias ElixirLS.LanguageServer.Providers.SymbolUtils
  alias ElixirLS.LanguageServer.{SourceFile, Parser}

  defmodule Info do
    defstruct [:type, :name, :detail, :location, :children, :selection_location, :symbol]
  end

  @macro_defs [:defmacro, :defmacrop, :defguard, :defguardp]
  @defs [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]

  @supplementing_attributes [
    :doc,
    :moduledoc,
    :typedoc,
    :spec,
    :impl,
    :deprecated
  ]

  def symbols(uri, %Parser.Context{ast: ast, source_file: source_file}, hierarchical) do
    symbols = extract_modules(ast) |> Enum.reject(&is_nil/1)

    {:ok, build_symbols(symbols, uri, source_file.text, hierarchical)}
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
       when defname in [:defmodule, :defprotocol, :defimpl_transformed] do
    module_info =
      case arguments do
        # Handles `defmodule do\nend` type compile errors
        [[do: module_body]] ->
          # The LSP requires us to return a non-empty name
          case defname do
            :defmodule -> {"MISSING_MODULE_NAME", nil, nil, module_body}
            :defprotocol -> {"MISSING_PROTOCOL_NAME", nil, nil, module_body}
          end

        [module_expression, [do: module_body]] ->
          {module_name_location, symbol} =
            case module_expression do
              {_, location, _} -> {location, Macro.to_string(module_expression)}
              _ -> {nil, nil}
            end

          # TODO extract module name location from Code.Fragment.surround_context?
          # TODO better selection ranges for defimpl?
          {extract_module_name(module_expression), symbol, module_name_location, module_body}

        _ ->
          nil
      end

    if module_info do
      {module_name, symbol, module_name_location, module_body} = module_info

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
          :defimpl_transformed -> :module
          :defprotocol -> :interface
        end

      %Info{
        type: type,
        name: symbol || module_name,
        detail: if(defname == :defimpl_transformed, do: :defimpl, else: defname) |> to_string,
        location: location,
        selection_location: module_name_location,
        children: module_symbols,
        symbol: symbol || module_name
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
      {:defimpl_transformed, location,
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
      detail: defname |> to_string,
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
        [{:"::", _, [{name, type_head_location, args} = _type_head | _]}] ->
          {{name, args}, type_head_location}

        [{:when, _, [{:"::", _, [{name, type_head_location, args} = _type_head, _]}, _]}] ->
          {{name, args}, type_head_location}

        [{name, type_head_location, args} = _type_head | _] ->
          {{name, args}, type_head_location}

        _ ->
          nil
      end

    if type_name_location do
      {{name, args}, type_head_location} = type_name_location

      type = if type_kind in [:type, :typep, :opaque], do: :class, else: :event

      name_str =
        try do
          to_string(name)
        rescue
          _ -> "__unknown__"
        end

      %Info{
        type: type,
        name: "#{name_str}/#{if(is_list(args), do: length(args), else: 0)}",
        detail: "@#{type_kind}",
        location: location,
        selection_location: type_head_location,
        symbol: name_str,
        children: []
      }
    end
  end

  # @behaviour BehaviourModule
  defp extract_symbol(_current_module, {:@, location, [{:behaviour, _, [behaviour_expression]}]}) do
    module_name = Macro.to_string(behaviour_expression)

    %Info{type: :interface, name: "@behaviour #{module_name}", location: location, children: []}
  end

  # Other attributes
  defp extract_symbol(_current_module, {:@, location, [{name, _, _}]}) when is_atom(name) do
    %Info{type: :enum_member, name: "@#{name}", location: location, children: []}
  end

  # Function, macro, guard with when
  defp extract_symbol(
         _current_module,
         {defname, location, [{:when, _, [{name, head_location, args} = _fn_head, _]} | _]}
       )
       when defname in @defs do
    name_str =
      try do
        to_string(name)
      rescue
        _ -> "__unknown__"
      end

    %Info{
      type: if(defname in @macro_defs, do: :constant, else: :function),
      symbol: name_str,
      name: "#{name_str}/#{if(is_list(args), do: length(args), else: 0)}",
      detail: defname |> to_string,
      location: location,
      selection_location: head_location,
      children: []
    }
  end

  # Function, macro, delegate
  defp extract_symbol(
         _current_module,
         {defname, location, [{name, head_location, args} = _fn_head | _]}
       )
       when defname in @defs do
    name_str =
      try do
        to_string(name)
      rescue
        _ -> "__unknown__"
      end

    %Info{
      type: if(defname in @macro_defs, do: :constant, else: :function),
      symbol: name_str,
      name: "#{name_str}/#{if(is_list(args), do: length(args), else: 0)}",
      detail: defname |> to_string,
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
      name: "#{name}",
      detail: :defrecord |> to_string,
      location: location |> Keyword.merge(Keyword.take(alias_location, [:line, :column])),
      children: children
    }
  end

  # ExUnit test
  defp extract_symbol(_current_module, {:test, location, [name | _]}) do
    %Info{
      type: :function,
      name: Macro.to_string(name),
      detail: :test |> to_string,
      location: location,
      children: []
    }
  end

  # ExUnit property
  defp extract_symbol(_current_module, {:property, location, [name | _]}) do
    %Info{
      type: :function,
      name: Macro.to_string(name),
      detail: :property |> to_string,
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
      name: Macro.to_string(name),
      detail: :describe |> to_string,
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

    %GenLSP.Structures.DocumentSymbol{
      name: info.name,
      detail: info.detail,
      kind: SymbolUtils.symbol_kind_to_code(info.type),
      range: range,
      selection_range: selection_range,
      children: build_symbol_information_hierarchical(uri, text, info.children)
    }
  end

  defp maybe_extend_range(
         %GenLSP.Structures.Range{
           start: %GenLSP.Structures.Position{line: start_line, character: start_character},
           end: %GenLSP.Structures.Position{line: end_line, character: end_character}
         },
         %GenLSP.Structures.Range{
           start: %GenLSP.Structures.Position{
             line: selection_start_line,
             character: selection_start_character
           },
           end: %GenLSP.Structures.Position{
             line: selection_end_line,
             character: selection_end_character
           }
         }
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

    %GenLSP.Structures.Range{
      start: %GenLSP.Structures.Position{
        line: extended_start_line,
        character: extended_start_character
      },
      end: %GenLSP.Structures.Position{line: extended_end_line, character: extended_end_character}
    }
  end

  defp build_symbol_information_flat(uri, text, info, parent_name \\ nil)

  defp build_symbol_information_flat(uri, text, info, parent_name) when is_list(info),
    do: Enum.map(info, &build_symbol_information_flat(uri, text, &1, parent_name))

  defp build_symbol_information_flat(uri, text, %Info{} = info, parent_name) do
    case info.children do
      [_ | _] ->
        [
          %GenLSP.Structures.SymbolInformation{
            name: info.name,
            kind: SymbolUtils.symbol_kind_to_code(info.type),
            location: %GenLSP.Structures.Location{
              uri: uri,
              range: location_to_range(info.location, text, nil)
            },
            container_name: parent_name
          }
          | Enum.map(info.children, &build_symbol_information_flat(uri, text, &1, info.name))
        ]

      _ ->
        %GenLSP.Structures.SymbolInformation{
          name: info.name,
          kind: SymbolUtils.symbol_kind_to_code(info.type),
          location: %GenLSP.Structures.Location{
            uri: uri,
            range: location_to_range(info.location, text, nil)
          },
          container_name: parent_name
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
          end_char = SourceFile.elixir_character_to_lsp(symbol, String.length(to_string(symbol)))
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
              Enum.at(lines, max(parent_end_line - 2, 0), "")
              |> String.length()

            SourceFile.elixir_position_to_lsp(
              lines,
              {parent_end_line - 1, end_of_expression + 1}
            )
          else
            # take end location from parent and assume end_of_expression is last char before final ; trimmed
            line = Enum.at(lines, parent_end_line - 1, "")
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

    %GenLSP.Structures.Range{
      start: %GenLSP.Structures.Position{line: start_line, character: start_character},
      end: %GenLSP.Structures.Position{line: end_line, character: end_character}
    }
  end

  defp extract_module_name(protocol: protocol, implementations: implementations) do
    extract_module_name(protocol) <> ", for: " <> extract_module_name(implementations)
  end

  defp extract_module_name(list) when is_list(list) do
    list_stringified = list |> Enum.map_join(", ", &extract_module_name/1)

    "[" <> list_stringified <> "]"
  end

  defp extract_module_name(module) when is_atom(module) do
    case Atom.to_string(module) do
      "Elixir." <> elixir_module_rest ->
        elixir_module_rest

      erlang_module ->
        erlang_module
    end
  end

  defp extract_module_name(other), do: Macro.to_string(other)

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
