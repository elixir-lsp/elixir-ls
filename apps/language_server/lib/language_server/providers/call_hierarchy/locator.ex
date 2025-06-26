defmodule ElixirLS.LanguageServer.Providers.CallHierarchy.Locator do
  @moduledoc """
  This module finds call hierarchy information for functions at the cursor position.
  Based on the References.Locator but adapted for call hierarchy needs.
  """

  alias ElixirSense.Core.Binding
  require ElixirSense.Core.Introspection, as: Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirSense.Core.State
  alias ElixirSense.Core.SurroundContext
  alias ElixirSense.Core.Parser
  require Logger

  def prepare(code, line, column, trace, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}) do
      :none ->
        # If no context, check if we're on a function definition line
        check_function_definition(code, line, column, trace, options)

      context ->
        metadata =
          Keyword.get_lazy(options, :metadata, fn ->
            Parser.parse_string(code, true, false, {line, column})
          end)

        env =
          %State.Env{module: module} =
          Metadata.get_cursor_env(metadata, {line, column}, {context.begin, context.end})

        attributes = get_attributes(metadata, module)

        # First try to find at cursor (for calls)
        result = find_at_cursor(context, env, attributes, metadata, trace)

        # If nothing found and we have a local_or_var context, check if it's a function definition
        if result == nil and match?({:local_or_var, _}, context.context) do
          check_function_definition_with_metadata(metadata, env.module, line, column)
        else
          result
        end
    end
  end

  def incoming_calls(name, _kind, _position, trace, options \\ []) do
    metadata = Keyword.get(options, :metadata)

    # Parse the function name to get module and function
    {module, function, arity} = parse_function_name(name)

    # Find all calls to this function in metadata (local calls in current file)
    metadata_calls = find_incoming_calls_in_metadata(module, function, arity, metadata)

    # Find all calls to this function in trace (remote calls from other files)
    trace_calls = find_incoming_calls_in_trace(module, function, arity, trace)

    # Combine and deduplicate
    (metadata_calls ++ trace_calls)
    |> Enum.uniq_by(fn %{from: from, from_ranges: ranges} ->
      {from.name, Enum.sort(ranges)}
    end)
  end

  def outgoing_calls(name, _kind, position, _trace, options \\ []) do
    metadata = Keyword.get(options, :metadata)

    # Parse the function name to get module and function
    {module, function, arity} = parse_function_name(name)

    # Find all calls made by this function in metadata
    find_outgoing_calls_in_metadata(module, function, arity, position, metadata)
  end

  defp get_attributes(metadata, module) do
    case Metadata.get_last_module_env(metadata, module) do
      %State.Env{attributes: attributes} -> attributes
      nil -> []
    end
  end

  defp find_at_cursor(
         context,
         %State.Env{
           aliases: aliases,
           module: module
         } = env,
         _attributes,
         %Metadata{
           mods_funs_to_positions: mods_funs,
           types: metadata_types
         } = metadata,
         _trace
       ) do
    binding_env = Binding.from_env(env, metadata, context.begin)
    type = SurroundContext.to_binding(context.context, module)

    case type do
      {:variable, _variable, _version} ->
        # Variables are not supported for call hierarchy
        nil

      {:attribute, _attribute} ->
        # Attributes are not supported for call hierarchy
        nil

      {:keyword, _} ->
        nil

      {{:atom, _alias}, nil} ->
        # Module references are not supported for call hierarchy (for now)
        nil

      {mod, function} when function != nil ->
        actual =
          {mod, function}
          |> expand(binding_env, module, aliases)
          |> Introspection.actual_mod_fun(
            env,
            mods_funs,
            metadata_types,
            context.begin,
            false
          )

        case actual do
          {actual_mod, actual_fun, true, :mod_fun} ->
            # Found a function, create call hierarchy item
            {line, column} = context.begin

            # Get the function arity from metadata
            arity = Metadata.get_call_arity(metadata, module, function, line, column) || :any

            # Try to find the function's definition location
            location = find_function_location(actual_mod, actual_fun, arity, mods_funs)

            if location do
              build_call_hierarchy_item(
                actual_mod,
                actual_fun,
                arity,
                location,
                mods_funs
              )
            else
              # If we can't find location in metadata, still create an item at cursor
              build_call_hierarchy_item_at_cursor(
                actual_mod,
                actual_fun,
                arity,
                context
              )
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp find_function_location(module, function, arity, mods_funs) do
    mods_funs
    |> Enum.find_value(fn
      {{^module, ^function, found_arity}, %{positions: [position | _]}}
      when arity == :any or found_arity == arity ->
        position

      _ ->
        nil
    end)
  end

  defp build_call_hierarchy_item(module, function, arity, {line, column}, mods_funs) do
    # Try to get more info about the function
    {{_m, _f, actual_arity}, _info} =
      Enum.find(mods_funs, fn
        {{^module, ^function, _}, _} -> true
        _ -> false
      end) || {{module, function, arity}, %{}}

    arity_str = if actual_arity == :any, do: "?", else: to_string(actual_arity)
    name = "#{inspect(module)}.#{function}/#{arity_str}"

    # Build a reasonable range - we'll use the position as both start and selection
    %{
      name: name,
      kind: GenLSP.Enumerations.SymbolKind.function(),
      tags: [],
      detail: nil,
      # Will be filled by the provider
      uri: nil,
      range: %{
        start: %{line: line || 1, column: column || 1},
        end: %{line: line || 1, column: (column || 1) + String.length(to_string(function))}
      },
      selection_range: %{
        start: %{line: line || 1, column: column || 1},
        end: %{line: line || 1, column: (column || 1) + String.length(to_string(function))}
      }
    }
  end

  defp build_call_hierarchy_item_at_cursor(module, function, arity, context) do
    {line, column} = context.begin
    arity_str = if arity == :any, do: "?", else: to_string(arity)
    name = "#{inspect(module)}.#{function}/#{arity_str}"

    %{
      name: name,
      kind: GenLSP.Enumerations.SymbolKind.function(),
      tags: [],
      detail: nil,
      uri: nil,
      range: %{
        start: %{line: line, column: column},
        end: %{line: line, column: column + String.length(to_string(function))}
      },
      selection_range: %{
        start: %{line: line, column: column},
        end: %{line: line, column: column + String.length(to_string(function))}
      }
    }
  end

  defp expand({nil, func}, _env, module, _aliases) when module != nil,
    do: {nil, func}

  defp expand({type, func}, env, _module, aliases) do
    case Binding.expand(env, type) do
      {:atom, module} -> {Introspection.expand_alias(module, aliases), func}
      _ -> {nil, nil}
    end
  end

  defp check_function_definition(code, line, column, _trace, options) do
    metadata =
      Keyword.get_lazy(options, :metadata, fn ->
        Parser.parse_string(code, true, false, {line, column})
      end)

    env = Metadata.get_cursor_env(metadata, {line, column})
    check_function_definition_with_metadata(metadata, env.module, line, column)
  end

  defp check_function_definition_with_metadata(metadata, module, line, column) do
    # Check if we're on a function definition by looking at mods_funs_to_positions
    metadata.mods_funs_to_positions
    |> Enum.find_value(fn
      {{mod, fun, arity}, %{positions: positions}} when mod == module ->
        if Enum.any?(positions, fn {pos_line, pos_col} ->
             # Check if cursor is on or near the function definition
             pos_line == line and abs(pos_col - column) <= String.length(to_string(fun))
           end) do
          # Found a function definition at this position
          {pos_line, pos_col} = List.first(positions)

          build_call_hierarchy_item(
            mod,
            fun,
            arity,
            {pos_line, pos_col},
            metadata.mods_funs_to_positions
          )
        else
          nil
        end

      _ ->
        nil
    end)
  end

  defp parse_function_name(name) do
    case Regex.run(~r/^(.+)\.([^.]+)\/(\d+|\?)$/, name) do
      [_, module_str, function_str, arity_str] ->
        # Convert module string to atom using Module.concat
        module = Module.concat([module_str])

        function = String.to_atom(function_str)
        arity = if arity_str == "?", do: :any, else: String.to_integer(arity_str)
        {module, function, arity}

      _ ->
        {nil, nil, nil}
    end
  end

  defp find_incoming_calls_in_metadata(module, function, arity, metadata) do
    if metadata == nil do
      []
    else
      all_calls = metadata.calls |> Map.values() |> List.flatten()

    filtered_calls =
      all_calls
      |> Enum.filter(fn call ->
        # Check for the specific function, module and arity
        call.func == function and
          call.mod == module and
          (arity == :any or call.arity == arity)
      end)

      group_calls_by_caller(filtered_calls, metadata)
    end
  end

  defp find_incoming_calls_in_trace(module, function, arity, trace) do
    trace
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(fn
      %{callee: {^module, ^function, callee_arity}} ->
        arity == :any or callee_arity == arity

      _ ->
        false
    end)
    |> group_trace_calls_by_caller()
  end

  defp group_calls_by_caller(calls, metadata) do
    calls
    |> Enum.group_by(fn call ->
      # Find which function this call is in
      find_containing_function(call.position, metadata)
    end)
    |> Enum.reject(fn {caller, _} -> caller == nil end)
    |> Enum.map(fn {caller_info, calls} ->
      %{
        from: caller_info,
        from_ranges: Enum.map(calls, &build_range_from_call/1)
      }
    end)
  end

  defp group_trace_calls_by_caller(trace_calls) do
    # Group trace calls by file first
    calls_by_file = Enum.group_by(trace_calls, & &1.file)
    
    # For each file, parse it to get metadata and find containing functions
    calls_by_file
    |> Enum.flat_map(fn {file, calls} ->
      case File.read(file) do
        {:ok, code} ->
          # Parse the file to get metadata
          metadata = Parser.parse_string(code, true, false, {1, 1})
          
          # Group calls by their containing function
          calls
          |> Enum.group_by(fn call ->
            position = {call.line, call.column}
            find_containing_function(position, metadata)
          end)
          |> Enum.reject(fn {caller, _} -> caller == nil end)
          |> Enum.map(fn {caller_info, calls} ->
            # Update caller_info with the file URI
            caller_info_with_uri = Map.put(caller_info, :uri, file)
            
            %{
              from: caller_info_with_uri,
              from_ranges: Enum.map(calls, &build_range_from_trace_call/1)
            }
          end)
          
        {:error, _} ->
          # If we can't read the file, skip these calls
          []
      end
    end)
  end

  defp find_containing_function({line, _column}, metadata) do
    # Collect all functions with their line ranges
    functions =
      metadata.mods_funs_to_positions
      |> Enum.filter(fn {_, info} ->
        positions = Map.get(info, :positions, [])
        positions != []
      end)
      |> Enum.map(fn {{module, function, arity}, info} ->
        positions = Map.get(info, :positions, [])
        {start_line, start_col} = List.first(positions)

        {start_line, module, function, arity, start_col}
      end)
      |> Enum.sort_by(fn {start_line, _, _, _, _} -> start_line end)

    # Find the function that contains this line
    # Look for the last function that starts before or at this line
    case functions
         |> Enum.reverse()
         |> Enum.find(fn {start_line, _, _, _, _} -> start_line <= line end) do
      {start_line, module, function, arity, start_col} ->
        %{
          name: "#{inspect(module)}.#{function}/#{arity}",
          kind: GenLSP.Enumerations.SymbolKind.function(),
          uri: nil,
          range: %{
            start: %{line: start_line, column: start_col},
            end: %{line: start_line, column: start_col + String.length(to_string(function))}
          },
          selection_range: %{
            start: %{line: start_line, column: start_col},
            end: %{line: start_line, column: start_col + String.length(to_string(function))}
          },
          tags: [],
          detail: nil
        }

      nil ->
        nil
    end
  end

  defp build_range_from_call(call) do
    {line, column} = call.position
    func_length = String.length(to_string(call.func))
    
    # Handle nil column
    column = column || 1

    %{
      start: %{line: line || 1, column: column},
      end: %{line: line || 1, column: column + func_length}
    }
  end

  defp build_range_from_trace_call(trace_call) do
    line = trace_call.line || 1
    column = trace_call.column || 1
    func = elem(trace_call.callee, 1)
    func_length = String.length(to_string(func))

    %{
      start: %{line: line, column: column},
      end: %{line: line, column: column + func_length}
    }
  end

  defp find_outgoing_calls_in_metadata(module, function, arity, _position, metadata) do
    if metadata == nil do
      []
    else
      # Get info about our function to find its line ranges
      our_function_info = 
        metadata.mods_funs_to_positions
        |> Enum.find_value(fn
          {{^module, ^function, ^arity}, info} -> info
          {{^module, ^function, _}, info} when arity == :any -> info
          _ -> nil
        end)
      
      if our_function_info do
        # Get start and end positions for our function
        positions = Map.get(our_function_info, :positions, [])
        end_positions = Map.get(our_function_info, :end_positions, [])
        
        if positions != [] do
          {start_line, _start_col} = List.first(positions)
          
          # Find the last end position that's not nil
          end_line = 
            if end_positions != [] do
              end_positions
              |> Enum.zip(positions)
              |> Enum.reverse()
              |> Enum.find_value(fn
                {nil, {pos_line, _}} -> pos_line + 10  # Heuristic: assume 10 lines if no end position
                {{end_line, _}, _} -> end_line
              end)
            else
              # If no end positions, use next function as boundary
              find_next_function_line(metadata.mods_funs_to_positions, module, start_line)
            end
          
          # Find all calls within our function's range
          calls =
            metadata.calls
            |> Map.values()
            |> List.flatten()
            |> Enum.filter(fn call ->
              {call_line, _} = call.position
              # Exclude def/defp/defmacro calls on the function definition line
              is_function_definition = call_line == start_line and 
                call.mod == Kernel and 
                call.func in [:def, :defp, :defmacro, :defmacrop]
              
              # Exclude alias references (they have nil func)
              is_alias_reference = call.func == nil and call.kind == :alias_reference
              
              !is_function_definition and
                !is_alias_reference and
                call_line >= start_line and 
                (end_line == nil or call_line <= end_line)
            end)
          
          # Group by callee
          calls
          |> Enum.group_by(fn call ->
            # For local calls (mod == nil), use the module from the current context
            callee_mod = call.mod || module
            {callee_mod, call.func, call.arity}
          end)
          |> Enum.map(fn {{mod, fun, call_arity}, calls} ->
            %{
              to: %{
                name: "#{inspect(mod)}.#{fun}/#{call_arity}",
                kind: GenLSP.Enumerations.SymbolKind.function(),
                uri: nil,
                range: build_range_from_call(List.first(calls)),
                selection_range: build_range_from_call(List.first(calls)),
                tags: [],
                detail: nil
              },
              from_ranges: Enum.map(calls, &build_range_from_call/1)
            }
          end)
        else
          []
        end
      else
        []
      end
    end
  end
  
  defp find_next_function_line(mods_funs, module, after_line) do
    mods_funs
    |> Enum.filter(fn
      {{^module, _, _}, info} -> 
        positions = Map.get(info, :positions, [])
        positions != [] and List.first(positions) |> elem(0) > after_line
      _ -> 
        false
    end)
    |> Enum.map(fn {_, info} ->
      Map.get(info, :positions, []) |> List.first() |> elem(0)
    end)
    |> Enum.min(fn -> nil end)
  end
end
