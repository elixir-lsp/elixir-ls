defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfo do
  @moduledoc """
  This module provides type information extraction for LLM consumption.
  
  It extracts types, specs, and callbacks from modules using both:
  - Explicit beam types from compiled modules
  - Dialyzer inferred contracts
  """

  alias ElixirSense.Core.Normalized.Typespec
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirSense.Core.TypeInfo
  alias ElixirSense.Core.Introspection
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser
  alias ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec.ContractTranslator
  require Logger

  @doc """
  Returns type information for a symbol (module, function, or type) given as string name.
  
  ## Parameters
    - symbol: The symbol name as a string (e.g., "Enum", "GenServer", "String.split/2", "String.t")
    - state: The language server state
  
  ## Returns
    - `{:ok, %{types: [...], specs: [...], callbacks: [...], dialyzer_contracts: [...]}}`
    - `{:ok, %{error: reason}}` on error
  """
  def execute([symbol_name], state) when is_binary(symbol_name) do
    try do
      case SymbolParser.parse(symbol_name) do
        {:ok, symbol_type, parsed} ->
          case extract_type_info_for_symbol(symbol_type, parsed, state) do
            {:ok, type_info} -> {:ok, type_info}
            {:error, reason} -> {:ok, %{error: reason}}
          end
          
        {:error, reason} ->
          {:ok, %{error: reason}}
      end
    catch
      kind, error ->
        Logger.error("Error in llmTypeInfo: #{Exception.format(kind, error, __STACKTRACE__)}")
        {:ok, %{error: "Failed to extract type information: #{inspect(error)}"}}
    end
  end

  def execute(_, _state) do
    {:ok, %{error: "Invalid arguments. Expected [symbol_name]"}}
  end

  defp extract_type_info_for_symbol(:module, module, state) do
    case Code.ensure_compiled(module) do
      {:module, actual_module} ->
        type_info = extract_type_info(actual_module, state)
        {:ok, type_info}
        
      {:error, reason} ->
        {:error, "Module not found or not compiled: #{inspect(reason)}"}
    end
  end

  defp extract_type_info_for_symbol(:remote_call, {module, function, arity}, state) do
    case Code.ensure_compiled(module) do
      {:module, actual_module} ->
        # Extract all type info from the module (same as for :module case)
        # then filter to only include the relevant function
        full_type_info = extract_type_info(actual_module, state)
        
        # Filter the results to only include the specific function/type/callback
        filtered_type_info = filter_type_info_by_function(full_type_info, function, arity)
        {:ok, filtered_type_info}
        
      {:error, reason} ->
        {:error, "Module not found or not compiled: #{inspect(reason)}"}
    end
  end

  defp extract_type_info_for_symbol(:local_call, {function, arity}, state) do
    # For local calls, try common modules like Kernel first
    extract_type_info_for_symbol(:remote_call, {Kernel, function, arity}, state)
  end

  defp extract_type_info_for_symbol(:attribute, _attribute, _state) do
    {:error, "Module attributes don't have type information"}
  end

  defp extract_type_info(module, state) do
    # Extract explicit types from beam
    types = extract_types(module)
    specs = extract_specs(module)
    callbacks = extract_callbacks(module)
    
    # Extract dialyzer contracts if available
    dialyzer_contracts = extract_dialyzer_contracts(module, state)
    
    %{
      module: inspect(module),
      types: types,
      specs: specs,
      callbacks: callbacks,
      dialyzer_contracts: dialyzer_contracts
    }
  end

  defp extract_function_dialyzer_contracts(module, function, arity, state) do
    all_contracts = extract_dialyzer_contracts(module, state)
    function_str = Atom.to_string(function)
    
    all_contracts
    |> Enum.filter(fn contract ->
      case String.split(contract.name, "/") do
        [^function_str, arity_str] ->
          contract_arity = String.to_integer(arity_str)
          arity == nil or contract_arity == arity
        _ ->
          false
      end
    end)
  end

  defp extract_types(module) do
    result = Typespec.get_types(module)
    
    case result do
      types when is_list(types) and length(types) > 0 ->        
        types
        |> Enum.filter(fn {kind, _} -> kind in [:type, :opaque] end)
        |> Enum.map(fn {_kind, {name, _, args}} = typedef ->
          format_type(typedef)
        end)
        |> Enum.sort_by(& &1.name)
        
      _ ->
        []
    end
  end

  defp extract_specs(module) do
    TypeInfo.get_module_specs(module)
    |> Enum.map(fn {_key, {{_name, _arity}, _spec_ast} = spec} ->
      format_spec(spec)
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp extract_callbacks(module) do
    result = TypeInfo.get_module_callbacks(module)
    |> Enum.map(fn {_key, {{_name, _arity}, _spec_ast} = callback} ->
      format_callback(callback)
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp extract_dialyzer_contracts(module, state) do
    try do
      # Get the source file for the module
      source = get_module_source(module)
      
      if source && is_map(state) && Map.has_key?(state, :__struct__) && 
         state.__struct__ == ElixirLS.LanguageServer.Server && state.analysis_ready? do
        # Convert to URI format
        uri = ElixirLS.LanguageServer.SourceFile.Path.to_uri(source)
        
        # Get contracts from the server which handles dialyzer state
        contracts = ElixirLS.LanguageServer.Server.suggest_contracts(uri)
        
        # Filter for this module and format
        contracts
        |> Enum.filter(fn {_file, _line, {mod, _, _}, _, _} -> mod == module end)
        |> Enum.map(&format_dialyzer_contract/1)
      else
        []
      end
    rescue
      error ->
        Logger.debug("Error extracting dialyzer contracts: #{inspect(error)}")
        []
    end
  end

  defp get_module_source(module) do
    if Code.ensure_loaded?(module) do
      case module.module_info(:compile)[:source] do
        source when is_list(source) -> List.to_string(source)
        _ -> nil
      end
    end
  end

  defp format_type({kind, {name, _ast, args}} = typedef) do
    arity = length(args)
    signature = format_type_signature(name, args)
    spec = try do
      TypeInfo.format_type_spec(typedef, line_length: 75)
    catch
      _ -> "@#{kind} #{name}/#{arity}"
    end

    %{
      name: "#{name}/#{arity}",
      kind: kind,
      signature: signature,
      spec: spec
    }
  end

  defp format_spec({{name, arity}, specs}) do
    # Transform macro names from internal form (MACRO-name/arity+1) to user-facing form (name/arity)
    {display_name, display_arity} = normalize_macro_name_and_arity(name, arity)
    signature = "#{display_name}/#{display_arity}"

    formatted_specs = Introspection.spec_to_string({{name, arity}, specs}, :spec)
    
    %{
      name: signature,
      specs: formatted_specs
    }
  end

  defp format_callback({{name, arity}, specs}) do
    # Transform macro names from internal form (MACRO-name/arity+1) to user-facing form (name/arity)
    {display_name, display_arity} = normalize_macro_name_and_arity(name, arity)
    signature = "#{display_name}/#{display_arity}"
    
    kind = if String.starts_with?(to_string(name), "MACRO-") do
      :macrocallback
    else
      :callback
    end

    formatted_specs = Introspection.spec_to_string({{name, arity}, specs}, kind)
    
    %{
      name: signature,
      specs: formatted_specs
    }
  end

  defp format_dialyzer_contract({_file, line, {mod, fun, arity}, success_typing, is_macro}) do
    # Transform macro names from internal form to user-facing form
    {display_name, display_arity} = normalize_macro_name_and_arity(fun, arity)
    
    # Use ContractTranslator to convert Erlang contract to Elixir spec
    elixir_spec = ContractTranslator.translate_contract(fun, success_typing, is_macro, mod)
    
    %{
      name: "#{display_name}/#{display_arity}",
      line: line,
      contract: "@spec #{elixir_spec}"
    }
  end

  defp format_type_signature(name, args) do
    arg_names = Enum.map_join(args, ", ", fn {_, _, name} -> Atom.to_string(name) end)
    "#{name}(#{arg_names})"
  end

  # Filters type info to only include items that match the given function name and arity
  defp filter_type_info_by_function(type_info, function, arity) do
    function_str = Atom.to_string(function)
    
    # Helper function to check if a name/arity matches our criteria
    match_function = fn item_name ->
      case String.split(item_name, "/") do
        [name, arity_str] ->
          # Check if name matches directly
          # The item names have already been normalized by normalize_macro_name_and_arity
          # so we can do a direct string comparison
          name_matches = name == function_str
          
          # Check arity if provided
          if arity != nil do
            case Integer.parse(arity_str) do
              {item_arity, ""} -> 
                # For macros, we need to be flexible with arity matching since
                # user might search for macro/0 but the actual macro has arity 1
                # The key insight is that if the names match, we should include it
                # regardless of minor arity discrepancies for macros
                name_matches and item_arity == arity
              _ -> 
                false
            end
          else
            # If no arity specified, match any arity with the same name
            name_matches
          end
        _ ->
          false
      end
    end
    
    # Filter types, specs, and callbacks
    filtered_types = Enum.filter(type_info.types, fn type -> match_function.(type.name) end)
    filtered_specs = Enum.filter(type_info.specs, fn spec -> match_function.(spec.name) end)
    filtered_callbacks = Enum.filter(type_info.callbacks, fn callback -> match_function.(callback.name) end)
    
    %{
      type_info |
      types: filtered_types,
      specs: filtered_specs,
      callbacks: filtered_callbacks
    }
  end

  # Transforms macro names from internal Elixir form to user-facing form
  # Internal: "MACRO-macro_name" with arity + 1
  # User-facing: "macro_name" with original arity
  defp normalize_macro_name_and_arity(name, arity) do
    name_str = to_string(name)
    
    if String.starts_with?(name_str, "MACRO-") do
      # Remove "MACRO-" prefix and subtract 1 from arity
      display_name = String.replace_prefix(name_str, "MACRO-", "")
      display_arity = arity - 1
      {display_name, display_arity}
    else
      # Regular function, no transformation needed
      {name_str, arity}
    end
  end
end
