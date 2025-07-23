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

  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser
  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([symbol], _state) when is_binary(symbol) do
    try do
      case SymbolParser.parse(symbol) do
        {:ok, :module, module} ->
          get_module_dependencies(module)

        {:ok, :remote_call, {module, function, arity}} ->
          # For remote calls, analyze the module and filter by the specific function
          get_module_dependencies_filtered_by_function(module, function, arity)

        {:ok, type, _parsed} ->
          {:ok,
           %{
             error:
               "Symbol type #{type} is not supported. Only modules are supported for dependency analysis."
           }}

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
    {:ok,
     %{
       error:
         "Invalid arguments: expected [symbol]. Example: 'MyApp.MyModule', 'Enum', or 'String.split/2'"
     }}
  end

  defp get_module_dependencies(module) do
    # Get direct dependencies from Tracer
    direct_deps = get_direct_dependencies(module)

    # Get reverse dependencies (modules that depend on this module)
    reverse_deps = get_reverse_dependencies(module)

    # Get transitive dependencies
    transitive_deps = get_transitive_dependencies_from_direct(module, direct_deps, :compile)

    reverse_transitive_deps =
      get_reverse_transitive_dependencies_from_direct(module, reverse_deps, :compile)

    formatted_direct = format_dependencies(direct_deps)
    formatted_reverse = format_dependencies(reverse_deps)

    {:ok,
     %{
       module: inspect(module),
       direct_dependencies: formatted_direct,
       reverse_dependencies: formatted_reverse,
       transitive_dependencies: format_module_list(transitive_deps),
       reverse_transitive_dependencies: format_module_list(reverse_transitive_deps)
     }}
  end

  defp get_module_dependencies_filtered_by_function(module, function, arity) do
    # Get direct dependencies from Tracer, filtered by specific function
    filtered_direct_deps = get_direct_dependencies_filtered_by_function(module, function, arity)

    # Get reverse dependencies (modules that depend on this module), filtered by specific function
    filtered_reverse_deps = get_reverse_dependencies_filtered_by_function(module, function, arity)

    # Get transitive dependencies using filtered dependencies for the first level
    transitive_deps =
      get_transitive_dependencies_from_direct(module, filtered_direct_deps, :compile)

    reverse_transitive_deps =
      get_reverse_transitive_dependencies_from_direct(module, filtered_reverse_deps, :compile)

    formatted_direct = format_dependencies(filtered_direct_deps)
    formatted_reverse = format_dependencies(filtered_reverse_deps)

    {:ok,
     %{
       module: inspect(module),
       function: "#{function}/#{arity || "nil"}",
       direct_dependencies: formatted_direct,
       reverse_dependencies: formatted_reverse,
       transitive_dependencies: format_module_list(transitive_deps),
       reverse_transitive_dependencies: format_module_list(reverse_transitive_deps)
     }}
  end

  defp get_direct_dependencies(module) do
    # Get all calls from this module
    calls =
      Tracer.get_trace()
      |> Enum.filter(fn {{callee_module, _, _}, call_infos} ->
        callee_module != module and
          Enum.any?(call_infos, fn info ->
            # Check if the call is from our module
            info.caller_module == module
          end)
      end)

    # Group by dependency type and reference type
    deps =
      Enum.reduce(
        calls,
        %{
          imports: MapSet.new(),
          aliases: MapSet.new(),
          requires: MapSet.new(),
          struct_expansions: MapSet.new(),
          function_calls: MapSet.new(),
          compile_deps: MapSet.new(),
          runtime_deps: MapSet.new(),
          exports_deps: MapSet.new()
        },
        fn {{callee_module, name, arity}, call_infos}, acc ->
          Enum.reduce(call_infos, acc, fn info, inner_acc ->
            # Track by reference type
            inner_acc =
              case info.reference_type do
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
                %{
                  inner_acc
                  | imports: MapSet.put(inner_acc.imports, {callee_module, name, arity})
                }

              kind when kind in [:alias_reference] ->
                %{inner_acc | aliases: MapSet.put(inner_acc.aliases, callee_module)}

              :require ->
                %{inner_acc | requires: MapSet.put(inner_acc.requires, callee_module)}

              :struct_expansion ->
                %{
                  inner_acc
                  | struct_expansions: MapSet.put(inner_acc.struct_expansions, callee_module)
                }

              kind when kind in [:remote_function, :remote_macro] ->
                %{
                  inner_acc
                  | function_calls:
                      MapSet.put(inner_acc.function_calls, {callee_module, name, arity})
                }

              _ ->
                inner_acc
            end
          end)
        end
      )

    deps
  end

  defp get_direct_dependencies_filtered_by_function(module, function, arity) do
    # Get all calls from this module but filter by specific function
    calls =
      Tracer.get_trace()
      |> Enum.filter(fn {{callee_module, _, _}, call_infos} ->
        callee_module != module and
          Enum.any?(call_infos, fn info ->
            # Check if the call is from our module AND the specific function
            info.caller_module == module and
              matches_function_call?(info.caller_function, function, arity)
          end)
      end)

    # Group by dependency type and reference type (same logic as get_direct_dependencies)
    deps =
      Enum.reduce(
        calls,
        %{
          imports: MapSet.new(),
          aliases: MapSet.new(),
          requires: MapSet.new(),
          struct_expansions: MapSet.new(),
          function_calls: MapSet.new(),
          compile_deps: MapSet.new(),
          runtime_deps: MapSet.new(),
          exports_deps: MapSet.new()
        },
        fn {{callee_module, name, call_arity}, call_infos}, acc ->
          # Only process call_infos that match our function
          matching_call_infos =
            Enum.filter(call_infos, fn info ->
              info.caller_module == module and
                matches_function_call?(info.caller_function, function, arity)
            end)

          Enum.reduce(matching_call_infos, acc, fn info, inner_acc ->
            # Track by reference type
            inner_acc =
              case info.reference_type do
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
                %{
                  inner_acc
                  | imports: MapSet.put(inner_acc.imports, {callee_module, name, call_arity})
                }

              kind when kind in [:alias_reference] ->
                %{inner_acc | aliases: MapSet.put(inner_acc.aliases, callee_module)}

              :require ->
                %{inner_acc | requires: MapSet.put(inner_acc.requires, callee_module)}

              :struct_expansion ->
                %{
                  inner_acc
                  | struct_expansions: MapSet.put(inner_acc.struct_expansions, callee_module)
                }

              kind when kind in [:remote_function, :remote_macro] ->
                %{
                  inner_acc
                  | function_calls:
                      MapSet.put(inner_acc.function_calls, {callee_module, name, call_arity})
                }

              _ ->
                inner_acc
            end
          end)
        end
      )

    deps
  end

  defp get_reverse_dependencies(module) do
    # Get all calls from this module
    calls =
      Tracer.get_trace()
      |> Enum.filter(fn {{callee_module, _, _}, _call_infos} ->
        # Check if the call is to our module
        callee_module == module
      end)

    # Group by dependency type and reference type
    deps =
      Enum.reduce(
        calls,
        %{
          imports: MapSet.new(),
          aliases: MapSet.new(),
          requires: MapSet.new(),
          struct_expansions: MapSet.new(),
          function_calls: MapSet.new(),
          compile_deps: MapSet.new(),
          runtime_deps: MapSet.new(),
          exports_deps: MapSet.new()
        },
        fn {{callee_module, name, arity}, call_infos}, acc ->
          Enum.reduce(call_infos, acc, fn
            %{caller_module: ^callee_module}, inner_acc ->
              # Skip self-references
              inner_acc

            info, inner_acc ->
              # Track by reference type
              inner_acc =
                case info.reference_type do
                  :compile ->
                    %{
                      inner_acc
                      | compile_deps: MapSet.put(inner_acc.compile_deps, info.caller_module)
                    }

                  :runtime ->
                    %{
                      inner_acc
                      | runtime_deps: MapSet.put(inner_acc.runtime_deps, info.caller_module)
                    }

                  :export ->
                    %{
                      inner_acc
                      | exports_deps: MapSet.put(inner_acc.exports_deps, info.caller_module)
                    }

                  _ ->
                    inner_acc
                end

              # Track by kind
              case info.kind do
                kind when kind in [:imported_function, :imported_macro] ->
                  %{
                    inner_acc
                    | imports:
                        MapSet.put(inner_acc.imports, %{
                          function: {callee_module, name, arity},
                          importing_module: info.caller_module
                        })
                  }

                kind when kind in [:alias_reference] ->
                  %{inner_acc | aliases: MapSet.put(inner_acc.aliases, info.caller_module)}

                :require ->
                  %{inner_acc | requires: MapSet.put(inner_acc.requires, info.caller_module)}

                :struct_expansion ->
                  %{
                    inner_acc
                    | struct_expansions:
                        MapSet.put(inner_acc.struct_expansions, info.caller_module)
                  }

                kind when kind in [:remote_function, :remote_macro] ->
                  %{
                    inner_acc
                    | function_calls:
                        MapSet.put(inner_acc.function_calls, %{
                          function: {callee_module, name, arity},
                          caller_module: info.caller_module
                        })
                  }

                _ ->
                  inner_acc
              end
          end)
        end
      )

    deps
  end

  defp get_reverse_dependencies_filtered_by_function(module, function, arity) do
    # Get all calls to this module but filter by specific function being called
    calls =
      Tracer.get_trace()
      |> Enum.filter(fn {{callee_module, callee_name, callee_arity}, call_infos} ->
        # Check if the call is to our module AND the specific function
        callee_module == module and
          matches_function_call?({callee_name, callee_arity}, function, arity) and
          Enum.any?(call_infos, fn _info -> true end)
      end)

    # Group by dependency type and reference type (same logic as get_reverse_dependencies)
    deps =
      Enum.reduce(
        calls,
        %{
          imports: MapSet.new(),
          aliases: MapSet.new(),
          requires: MapSet.new(),
          struct_expansions: MapSet.new(),
          function_calls: MapSet.new(),
          compile_deps: MapSet.new(),
          runtime_deps: MapSet.new(),
          exports_deps: MapSet.new()
        },
        fn {{callee_module, name, call_arity}, call_infos}, acc ->
          Enum.reduce(call_infos, acc, fn
            %{caller_module: ^callee_module}, inner_acc ->
              # Skip self-references
              inner_acc

            info, inner_acc ->
              # Track by reference type
              inner_acc =
                case info.reference_type do
                  :compile ->
                    %{
                      inner_acc
                      | compile_deps: MapSet.put(inner_acc.compile_deps, info.caller_module)
                    }

                  :runtime ->
                    %{
                      inner_acc
                      | runtime_deps: MapSet.put(inner_acc.runtime_deps, info.caller_module)
                    }

                  :export ->
                    %{
                      inner_acc
                      | exports_deps: MapSet.put(inner_acc.exports_deps, info.caller_module)
                    }

                  _ ->
                    inner_acc
                end

              # Track by kind
              case info.kind do
                kind when kind in [:imported_function, :imported_macro] ->
                  %{
                    inner_acc
                    | imports:
                        MapSet.put(inner_acc.imports, %{
                          function: {callee_module, name, call_arity},
                          importing_module: info.caller_module
                        })
                  }

                kind when kind in [:alias_reference] ->
                  %{inner_acc | aliases: MapSet.put(inner_acc.aliases, info.caller_module)}

                :require ->
                  %{inner_acc | requires: MapSet.put(inner_acc.requires, info.caller_module)}

                :struct_expansion ->
                  %{
                    inner_acc
                    | struct_expansions:
                        MapSet.put(inner_acc.struct_expansions, info.caller_module)
                  }

                kind when kind in [:remote_function, :remote_macro] ->
                  %{
                    inner_acc
                    | function_calls:
                        MapSet.put(inner_acc.function_calls, %{
                          function: {callee_module, name, call_arity},
                          caller_module: info.caller_module
                        })
                  }

                _ ->
                  inner_acc
              end
          end)
        end
      )

    deps
  end

  # Helper function to check if a caller function matches the function we're filtering for
  defp matches_function_call?({caller_name, caller_arity}, target_function, target_arity) do
    caller_name_str = Atom.to_string(caller_name)
    target_function_str = Atom.to_string(target_function)

    name_matches = caller_name_str == target_function_str

    if target_arity == nil do
      # If no arity specified, match any arity with the same name
      name_matches
    else
      # Match both name and arity
      name_matches and caller_arity == target_arity
    end
  end

  defp matches_function_call?(caller_function, target_function, _target_arity)
       when is_atom(caller_function) do
    # Handle single atom case (no arity info available)
    caller_function_str = Atom.to_string(caller_function)
    target_function_str = Atom.to_string(target_function)
    caller_function_str == target_function_str
  end

  defp matches_function_call?(nil, _target_function, _target_arity) do
    # If caller_function is nil, this is a module-level call (e.g., compile-time)
    # We should include these since they could be related to the function
    false
  end

  defp get_transitive_dependencies_from_direct(module, direct_dependencies, type) do
    all_direct_modules =
      case type do
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
      all_direct_modules =
        case type do
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
    all_direct_modules =
      case type do
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
      all_direct_modules =
        case type do
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
end
