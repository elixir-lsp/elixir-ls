defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmModuleDependencies do
  @moduledoc """
  This module implements a custom command for getting module dependency information,
  optimized for LLM consumption.
  
  Returns information about:
  - Direct dependencies (modules this module uses)
  - Reverse dependencies (modules that use this module)  
  - Transitive dependencies
  - Alias mappings
  - Import/require relationships
  """

  alias ElixirLS.LanguageServer.{SourceFile, Tracer}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser
  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([symbol], state) when is_binary(symbol) do
    try do
      case SymbolParser.parse(symbol) do
        {:ok, :module, module} ->
          get_module_dependencies(module, state)
        
        {:ok, :remote_call, {module, _, _}} ->
          # For remote calls, analyze the module part
          get_module_dependencies(module, state)
          
        {:ok, type, _parsed} ->
          {:ok, %{error: "Symbol type #{type} is not supported. Only modules are supported for dependency analysis."}}
          
        {:error, reason} ->
          {:ok, %{error: "Failed to parse symbol: #{reason}"}}
      end
    rescue
      error ->
        Logger.error("Error in llmModuleDependencies: #{inspect(error)}")
        {:ok, %{error: "Internal error: #{Exception.message(error)}"}}
    end
  end

  def execute(_args, _state) do
    {:ok, %{error: "Invalid arguments: expected [symbol]. Example: 'MyApp.MyModule', 'Enum', or 'String.split/2'"}}
  end


  defp get_module_dependencies(module, state) do
    # Get direct dependencies from Tracer
    direct_deps = get_direct_dependencies(module)
    
    # Get reverse dependencies (modules that depend on this module)
    reverse_deps = get_reverse_dependencies(module)
    
    # Get module info from state if available
    module_info = get_module_info(module, state)
    
    # Get transitive dependencies
    transitive_deps = get_transitive_dependencies_from_direct(module, direct_deps, :compile)

    reverse_transitive_deps = get_reverse_transitive_dependencies_from_direct(module, reverse_deps, :compile)

    formatted_direct = format_dependencies(direct_deps)
    formatted_reverse = format_dependencies(reverse_deps)
    
    {:ok, %{
      module: inspect(module),
      location: module_info[:location],
      direct_dependencies: formatted_direct,
      reverse_dependencies: formatted_reverse,
      transitive_dependencies: format_module_list(transitive_deps),
      reverse_transitive_dependencies: format_module_list(reverse_transitive_deps),
      # Add top-level convenience fields for backward compatibility
      # TODO: Remove duplicated info
      compile_time_dependencies: formatted_direct.compile_dependencies,
      runtime_dependencies: formatted_direct.runtime_dependencies,
      exports_dependencies: formatted_direct.exports_dependencies
    }}
  end

  # TODO: WTF? don't need that
  defp get_module_info(module, state) do
    # Try to find module definition in source files
    case find_module_in_sources(module, state) do
      {:ok, info} -> info
      _ -> %{}
    end
  end

  defp find_module_in_sources(module, state) do
    # Check all source files for module definition
    Enum.find_value(state.source_files, fn {uri, %SourceFile{} = source_file} ->
      if String.contains?(source_file.text, "defmodule #{inspect(module)}") do
        {:ok, %{location: %{uri: uri}}}
      end
    end)
  end

  defp get_direct_dependencies(module) do
    # Get all calls from this module
    calls = Tracer.get_trace()
            |> Enum.filter(fn {{callee_module, _, _}, call_infos} ->
              callee_module != module and
              Enum.any?(call_infos, fn info ->
                # Check if the call is from our module
                info.caller_module == module
                # TODO: WTF?
                # ||
                # (info.file && get_caller_module(info.file) == module)
              end)
            end)
    
    # Group by dependency type and reference type
    deps = Enum.reduce(calls, %{
      imports: MapSet.new(),
      aliases: MapSet.new(),
      requires: MapSet.new(),
      struct_expansions: MapSet.new(),
      function_calls: MapSet.new(),
      compile_deps: MapSet.new(),
      runtime_deps: MapSet.new(),
      exports_deps: MapSet.new()
    }, fn {{callee_module, name, arity}, call_infos}, acc ->
      Enum.reduce(call_infos, acc, fn info, inner_acc ->
        # Track by reference type
        inner_acc = case info.reference_type do
          :compile ->
            %{inner_acc | compile_deps: MapSet.put(inner_acc.compile_deps, callee_module)}
          :runtime ->
            %{inner_acc | runtime_deps: MapSet.put(inner_acc.runtime_deps, callee_module)}
          :export ->
            %{inner_acc | exports_deps: MapSet.put(inner_acc.exports_deps, callee_module)}
          _ ->
            inner_acc
        end
        
        # Track by kind
        case info.kind do
          kind when kind in [:imported_function, :imported_macro] ->
            %{inner_acc | imports: MapSet.put(inner_acc.imports, {callee_module, name, arity})}
            
          kind when kind in [:alias_reference] ->
            %{inner_acc | aliases: MapSet.put(inner_acc.aliases, callee_module)}
            
          :require ->
            %{inner_acc | requires: MapSet.put(inner_acc.requires, callee_module)}

          :struct_expansion ->
            %{inner_acc | struct_expansions: MapSet.put(inner_acc.struct_expansions, callee_module)}
            
          kind when kind in [:remote_function, :remote_macro] ->
            %{inner_acc | function_calls: MapSet.put(inner_acc.function_calls, {callee_module, name, arity})}
            
          _ ->
            inner_acc
        end
      end)
    end)
    
    deps
  end

  defp get_reverse_dependencies(module) do
    # Get all calls from this module
    calls = Tracer.get_trace()
            |> Enum.filter(fn {{callee_module, _, _}, call_infos} ->
              # Check if the call is to our module
              callee_module == module
            end)
    
    # Group by dependency type and reference type
    deps = Enum.reduce(calls, %{
      imports: MapSet.new(),
      aliases: MapSet.new(),
      requires: MapSet.new(),
      struct_expansions: MapSet.new(),
      function_calls: MapSet.new(),
      compile_deps: MapSet.new(),
      runtime_deps: MapSet.new(),
      exports_deps: MapSet.new()
    }, fn {{callee_module, name, arity}, call_infos}, acc ->
      Enum.reduce(call_infos, acc, fn
      %{caller_module: ^callee_module}, inner_acc ->
        # Skip self-references
        inner_acc
      info, inner_acc ->
        # Track by reference type
        inner_acc = case info.reference_type do
          :compile ->
            %{inner_acc | compile_deps: MapSet.put(inner_acc.compile_deps, info.caller_module)}
          :runtime ->
            %{inner_acc | runtime_deps: MapSet.put(inner_acc.runtime_deps, info.caller_module)}
          :export ->
            %{inner_acc | exports_deps: MapSet.put(inner_acc.exports_deps, info.caller_module)}
          _ ->
            inner_acc
        end
        
        # Track by kind
        case info.kind do
          kind when kind in [:imported_function, :imported_macro] ->
            %{inner_acc | imports: MapSet.put(inner_acc.imports, %{function: {callee_module, name, arity}, importing_module: info.caller_module})}

          kind when kind in [:alias_reference] ->
            %{inner_acc | aliases: MapSet.put(inner_acc.aliases, info.caller_module)}
            
          :require ->
            %{inner_acc | requires: MapSet.put(inner_acc.requires, info.caller_module)}

          :struct_expansion ->
            %{inner_acc | struct_expansions: MapSet.put(inner_acc.struct_expansions, info.caller_module)}
            
          kind when kind in [:remote_function, :remote_macro] ->
            %{inner_acc | function_calls: MapSet.put(inner_acc.function_calls, %{function: {callee_module, name, arity}, caller_module: info.caller_module})}
            
          _ ->
            inner_acc
        end
      end)
    end)
    
    deps
  end

  defp get_caller_module(file) do
    # Get module that owns this file from Tracer
    case Tracer.get_modules_by_file(file) do
      [{module, _info} | _] -> module
      _ -> nil
    end
  end

  defp extract_function_calls_to_module(module) do
    Tracer.get_trace()
    |> Enum.filter(fn {{callee_module, _, _}, _} -> callee_module == module end)
    |> Enum.flat_map(fn {{_, name, arity}, call_infos} ->
      Enum.map(call_infos, fn info ->
        %{
          function: "#{name}/#{arity}",
          caller_file: info.file,
          caller_module: get_caller_module(info.file),
          line: info.line,
          column: info.column
        }
      end)
    end)
    |> Enum.filter(fn call -> call.caller_module != nil end)
  end

  defp get_transitive_dependencies_from_direct(module, direct_dependencies, type) do
    all_direct_modules = case type do
        :compile -> direct_dependencies.compile_deps
        :export -> direct_dependencies.exports_deps
        :runtime -> direct_dependencies.runtime_deps
      end

    Enum.reduce(all_direct_modules, MapSet.new([module]), fn dep, acc ->
      get_transitive_dependencies(dep, type, acc)
    end)
    |> MapSet.delete(module)
    |> MapSet.difference(all_direct_modules)
  end

  defp get_transitive_dependencies(module, type, visited) do
    if MapSet.member?(visited, module) do
      visited
    else
      visited = MapSet.put(visited, module)
      direct = get_direct_dependencies(module)
      
      # Get all directly referenced modules (both compile and runtime)
      all_direct_modules = case type do
        :compile -> direct.compile_deps
        :export -> direct.exports_deps
        :runtime -> direct.runtime_deps
      end
      
      # Recursively get dependencies
      Enum.reduce(all_direct_modules, visited, fn dep_module, acc ->
        get_transitive_dependencies(dep_module, type, acc)
      end)
    end
  end

  defp get_reverse_transitive_dependencies_from_direct(module, direct_dependencies, type) do
    all_direct_modules = case type do
        :compile -> direct_dependencies.compile_deps
        :export -> direct_dependencies.exports_deps
        :runtime -> direct_dependencies.runtime_deps
      end

    Enum.reduce(all_direct_modules, MapSet.new([module]), fn dep, acc ->
      get_reverse_transitive_dependencies(dep, type, acc)
    end)
    |> MapSet.delete(module)
    |> MapSet.difference(all_direct_modules)
  end

  defp get_reverse_transitive_dependencies(module, type, visited) do
    if MapSet.member?(visited, module) do
      visited
    else
      visited = MapSet.put(visited, module)
      direct = get_reverse_dependencies(module)
      
      # Get all directly referenced modules (both compile and runtime)
      all_direct_modules = case type do
        :compile -> direct.compile_deps
        :export -> direct.exports_deps
        :runtime -> direct.runtime_deps
      end
      
      # Recursively get dependencies
      Enum.reduce(all_direct_modules, visited, fn dep_module, acc ->
        get_reverse_transitive_dependencies(dep_module, type, acc)
      end)
    end
  end

  defp format_dependencies(deps) when is_map(deps) do
    %{
      imports: format_mfa_list(deps.imports),
      aliases: format_module_list(deps.aliases),
      requires: format_module_list(deps.requires),
      struct_expansions: format_module_list(deps.struct_expansions),
      function_calls: format_mfa_list(deps.function_calls),
      compile_dependencies: format_module_list(deps.compile_deps),
      runtime_dependencies: format_module_list(deps.runtime_deps),
      exports_dependencies: format_module_list(deps.exports_deps)
    }
  end

  defp format_module_list(modules) when is_struct(modules, MapSet) do
    modules
    |> MapSet.to_list()
    |> Enum.map(&inspect/1)
    |> Enum.sort()
  end

  defp format_module_list(modules) when is_list(modules) do
    modules
    |> Enum.map(&inspect/1)
    |> Enum.sort()
  end

  defp format_mfa(mfa) when is_tuple(mfa) do
    {mod, fun, arity} = mfa
    "#{inspect(mod)}.#{fun}/#{arity}"
  end
  defp format_mfa(mfa) when is_map(mfa) do
    case mfa do
      %{function: {mod, fun, arity}, caller_module: caller_mod} ->
        "#{inspect(caller_mod)} calls #{inspect(mod)}.#{fun}/#{arity}"
      %{function: {mod, fun, arity}, importing_module: caller_mod} ->
        "#{inspect(caller_mod)} imports #{inspect(mod)}.#{fun}/#{arity}"
      _ ->
        inspect(mfa)
    end
  end

  defp format_mfa_list(mfa) when is_struct(mfa, MapSet) do
    mfa
    |> MapSet.to_list()
    |> Enum.map(&format_mfa/1)
    |> Enum.sort()
  end

  defp format_mfa_list(mfa) when is_list(mfa) do
    mfa
    |> Enum.map(&format_mfa/1)
    |> Enum.sort()
  end

  defp format_function_calls(calls) when is_list(calls) do
    calls
    |> Enum.map(fn
      %{function: fun, caller_module: mod} ->
        %{
          function: fun,
          caller_module: inspect(mod)
        }
      _ -> nil
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort_by(& &1.function)
  end
end
