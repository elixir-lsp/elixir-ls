defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmEnvironment do
  @moduledoc """
  This module implements a custom command for getting environment information
  at a specific position in code, optimized for LLM consumption.
  
  Returns information about the current context including:
  - Module and function context
  - Available aliases and imports
  - Variables in scope
  - Module attributes
  - Behaviours implemented
  """

  alias ElixirSense.Core.{Metadata, Parser, State}
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirLS.LanguageServer.SourceFile

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([location], state) when is_binary(location) do
    try do
      case parse_location(location) do
        {:ok, uri, line, column} ->
          get_environment_at_position(uri, line, column, state)
          
        {:error, reason} ->
          {:ok, %{error: "Invalid location format: #{reason}"}}
      end
    rescue
      error ->
        Logger.error("Error in llmEnvironment: #{inspect(error)}")
        {:ok, %{error: "Internal error: #{Exception.message(error)}"}}
    end
  end

  def execute(_args, _state) do
    {:ok, %{error: "Invalid arguments: expected [location_string]. Examples: 'file.ex:10:5' or 'lib/my_module.ex:25'"}}
  end

  # Parse location strings like:
  # - "file.ex:10:5" (file:line:column)
  # - "lib/my_module.ex:25" (file:line, column defaults to 1)
  # - "file://path/to/file.ex:10:5" (with URI)
  defp parse_location(location) do
    cond do
      # URI format with line and column
      String.match?(location, ~r/^file:\/\/.*:\d+:\d+$/) ->
        parts = String.split(location, ":")
        uri = Enum.slice(parts, 0..-3//1) |> Enum.join(":")
        [line_str, column_str] = Enum.slice(parts, -2..-1)
        
        {:ok, uri, String.to_integer(line_str), String.to_integer(column_str)}
        
      # URI format with line only
      String.match?(location, ~r/^file:\/\/.*:\d+$/) ->
        parts = String.split(location, ":")
        uri = Enum.slice(parts, 0..-2//1) |> Enum.join(":")
        line_str = List.last(parts)
        
        {:ok, uri, String.to_integer(line_str), 1}
        
      # Path format with line and column
      String.match?(location, ~r/^.*\.exs?:\d+:\d+$/) ->
        parts = String.split(location, ":")
        path = Enum.slice(parts, 0..-3//1) |> Enum.join(":")
        [line_str, column_str] = Enum.slice(parts, -2..-1)
        
        # Convert to file URI
        uri = SourceFile.Path.to_uri(path)
        {:ok, uri, String.to_integer(line_str), String.to_integer(column_str)}
        
      # Path format with line only
      String.match?(location, ~r/^.*\.exs?:\d+$/) ->
        parts = String.split(location, ":")
        path = Enum.slice(parts, 0..-2//1) |> Enum.join(":")
        line_str = List.last(parts)
        
        # Convert to file URI
        uri = SourceFile.Path.to_uri(path)
        {:ok, uri, String.to_integer(line_str), 1}
        
      true ->
        {:error, "Unrecognized location format. Use 'file.ex:line:column' or 'file.ex:line'"}
    end
  end

  defp get_environment_at_position(uri, line, column, state) do
    case state.source_files[uri] do
      %SourceFile{text: text} ->
        # Parse the file
        metadata = Parser.parse_string(text, true, false, {line, column})
        
        # Get context at cursor
        context = NormalizedCode.Fragment.surround_context(text, {line, column})
        
        # Get environment
        env = if context != :none do
          Metadata.get_cursor_env(metadata, {line, column}, {context.begin, context.end})
        else
          # Fallback to just position
          Metadata.get_cursor_env(metadata, {line, column})
        end
        
        # Format environment for LLM consumption
        env_info = format_environment(env, metadata, uri, line, column)
        
        {:ok, env_info}
        
      nil ->
        {:ok, %{error: "File not found in workspace: #{uri}"}}
    end
  end

  defp format_environment(env = %ElixirSense.Core.State.Env{}, metadata = %ElixirSense.Core.Metadata{}, uri, line, column) do
    # Extract the most useful information for LLMs
    %{
      location: %{
        uri: uri,
        line: line,
        column: column
      },
      context: %{
        module: env.module,
        function: format_function_context(env.function),
        # Include surrounding context if available
        context_type: env.context
      },
      aliases: format_aliases(env.aliases),
      imports: format_imports(env.functions ++ env.macros),
      requires: env.requires,
      variables: format_variables(env.vars),
      attributes: format_attributes(env.attributes),
      behaviours_implemented: env.behaviours,
      # Include some metadata statistics
      definitions: %{
        modules_defined: extract_modules_from_metadata(metadata),
        types_defined: format_types_from_metadata(metadata),
        functions_defined: format_functions_from_metadata(metadata),
        callbacks_defined: format_callbacks_from_metadata(metadata)
      }
    }
  end

  defp format_function_context(nil), do: nil
  defp format_function_context({name, arity}), do: "#{name}/#{arity}"

  defp format_aliases(aliases) do
    aliases
    |> Enum.map(fn {alias_name, actual_module} ->
      %{
        alias: inspect(alias_name),
        module: inspect(actual_module)
      }
    end)
    |> Enum.sort_by(& &1.alias)
  end

  defp format_imports(functions_and_macros) do
    functions_and_macros
    |> Enum.flat_map(fn {module, funs} ->
      Enum.map(funs, fn {name, arity} ->
        %{
          module: inspect(module),
          function: "#{name}/#{arity}"
        }
      end)
    end)
    |> Enum.sort_by(& &1.function)
  end

  defp format_variables(vars) do
    vars
    |> Enum.map(fn var_info ->
      %{
        name: to_string(var_info.name),
        type: format_var_type(var_info.type),
        version: var_info.version
      }
    end)
    |> Enum.sort_by(& &1.name)
  end
  
  # Basic atomic types
  defp format_var_type(:none), do: %{type: "none"}
  defp format_var_type(:empty), do: %{type: "empty"}
  defp format_var_type(:no_spec), do: %{type: "no_spec"}
  defp format_var_type(nil), do: %{type: "any"}

  # Basic value types
  defp format_var_type({:atom, atom}), do: %{type: "atom", value: atom}
  defp format_var_type({:integer, value}), do: %{type: "integer", value: value}
  defp format_var_type({:boolean, value}), do: %{type: "boolean", value: value}
  defp format_var_type({:binary, _}), do: %{type: "binary"}
  defp format_var_type({:bitstring, _}), do: %{type: "bitstring"}
  defp format_var_type({:number, _}), do: %{type: "number"}

  # Container types
  defp format_var_type({:map, fields, updated_map}) do
    %{
      type: "map",
      fields: format_type_fields(fields),
      updated_from: format_var_type(updated_map)
    }
  end

  defp format_var_type({:map, fields}) do
    %{
      type: "map", 
      fields: format_type_fields(fields)
    }
  end

  defp format_var_type({:struct, fields, struct_type, updated_struct}) do
    %{
      type: "struct",
      module: format_struct_type(struct_type),
      fields: format_type_fields(fields),
      updated_from: format_var_type(updated_struct)
    }
  end

  defp format_var_type({:struct, fields, struct_type}) do
    %{
      type: "struct",
      module: format_struct_type(struct_type),
      fields: format_type_fields(fields)
    }
  end

  defp format_var_type({:tuple, size, fields}) do
    %{
      type: "tuple",
      size: size,
      elements: Enum.map(fields, &format_var_type/1)
    }
  end

  defp format_var_type({:list, element_type}) do
    %{
      type: "list",
      element_type: format_var_type(element_type)
    }
  end

  # Variable and reference types
  defp format_var_type({:variable, name, version}) do
    %{
      type: "variable",
      name: name,
      version: version
    }
  end

  defp format_var_type({:attribute, attribute}) do
    %{
      type: "attribute",
      name: attribute
    }
  end

  # Function call types
  defp format_var_type({:call, target, function, arguments}) do
    %{
      type: "call",
      target: format_var_type(target),
      function: function,
      arguments: Enum.map(arguments, &format_var_type/1)
    }
  end

  defp format_var_type({:local_call, function, position, arguments}) do
    %{
      type: "local_call",
      function: function,
      position: position,
      arguments: Enum.map(arguments, &format_var_type/1)
    }
  end

  # Access and manipulation types
  defp format_var_type({:map_key, map_candidate, key_candidate}) do
    %{
      type: "map_key",
      map: format_var_type(map_candidate),
      key: format_var_type(key_candidate)
    }
  end

  defp format_var_type({:tuple_nth, tuple_candidate, n}) do
    %{
      type: "tuple_nth",
      tuple: format_var_type(tuple_candidate),
      index: n
    }
  end

  defp format_var_type({:for_expression, list_candidate}) do
    %{
      type: "for_expression",
      enumerable: format_var_type(list_candidate)
    }
  end

  defp format_var_type({:list_head, list_candidate}) do
    %{
      type: "list_head",
      list: format_var_type(list_candidate)
    }
  end

  defp format_var_type({:list_tail, list_candidate}) do
    %{
      type: "list_tail",
      list: format_var_type(list_candidate)
    }
  end

  # Composite types
  defp format_var_type({:union, types}) do
    %{
      type: "union",
      types: Enum.map(types, &format_var_type/1)
    }
  end

  defp format_var_type({:intersection, types}) do
    %{
      type: "intersection",
      types: Enum.map(types, &format_var_type/1)
    }
  end

  # Fallback for unknown types
  defp format_var_type(other) do
    %{type: "unknown", raw: inspect(other)}
  end

  # Helper functions
  defp format_type_fields(fields) when is_list(fields) do
    Enum.map(fields, fn {key, type} ->
      %{key: key, type: format_var_type(type)}
    end)
  end

  defp format_type_fields(other), do: inspect(other)

  defp format_struct_type({:atom, module}), do: inspect(module)
  defp format_struct_type({:attribute, attr}), do: "@#{attr}"
  defp format_struct_type(nil), do: nil
  defp format_struct_type(other), do: inspect(other)

  defp format_attributes(attributes) do
    attributes
    |> Enum.map(fn attr_info ->
      %{
        name: to_string(attr_info.name),
        type: format_var_type(attr_info.type)
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp format_types(types) do
    types
    |> Enum.map(fn {{module, name, arity}, _info} ->
      "#{inspect(module)}.#{name}/#{arity}"
    end)
    |> Enum.sort()
  end
  
  defp extract_modules_from_metadata(metadata = %ElixirSense.Core.Metadata{}) do
    metadata.mods_funs_to_positions
    |> Map.keys()
    |> Enum.map(fn
      {module, nil, nil} -> module
      {module, _, _} -> module
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp format_functions_from_metadata(metadata = %ElixirSense.Core.Metadata{}) do
    metadata.mods_funs_to_positions
    |> Map.keys()
    |> Enum.filter(fn {_mod, fun, _} -> fun != nil end)
    |> Enum.sort()
    |> Enum.map(fn {mod, fun, arity} -> "#{inspect(mod)}.#{fun}/#{arity}" end)
  end
  
  defp format_types_from_metadata(metadata = %ElixirSense.Core.Metadata{}) do
    metadata.types
    |> Map.keys()
    |> Enum.filter(fn {_mod, fun, _} -> fun != nil end)
    |> Enum.sort()
    |> Enum.map(fn {mod, fun, arity} -> "#{inspect(mod)}.#{fun}/#{arity}" end)
  end

  defp format_callbacks_from_metadata(metadata) do
    metadata.specs
    |> Enum.filter(fn {{_mod, fun, _}, %State.SpecInfo{} = info} -> info.kind in [:callback, :macrocallback] end)
    |> Enum.map(fn {{mod, fun, arity}, _info} -> {mod, fun, arity} end)
    |> Enum.sort()
    |> Enum.map(fn {mod, fun, arity} -> "#{inspect(mod)}.#{fun}/#{arity}" end)
  end
end
