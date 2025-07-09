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
  require Logger

  @doc """
  Returns type information for a module given as string name.
  
  ## Parameters
    - module: The module name as a string (e.g., "Enum", "GenServer")
    - state: The language server state
  
  ## Returns
    - `{:ok, %{types: [...], specs: [...], callbacks: [...], dialyzer_contracts: [...]}}`
    - `{:ok, %{error: reason}}` on error
  """
  def execute([module_name], state) when is_binary(module_name) do
    try do
      # Handle both full module names and aliases
      module = 
        case module_name do
          "Elixir." <> _ -> Module.concat([module_name])
          ":" <> erlang_module -> String.to_atom(erlang_module)
          _ -> Module.concat([module_name])
        end
      
      # Ensure module is loaded and compiled
      case Code.ensure_compiled(module) do
        {:module, actual_module} ->
          type_info = extract_type_info(actual_module, state)
          {:ok, type_info}
          
        {:error, reason} ->
          {:ok, %{error: "Module not found or not compiled: #{inspect(reason)}"}}
      end
    catch
      kind, error ->
        Logger.error("Error in llmTypeInfo: #{Exception.format(kind, error, __STACKTRACE__)}")
        {:ok, %{error: "Failed to extract type information: #{inspect(error)}"}}
    end
  end

  def execute(_, _state) do
    {:ok, %{error: "Invalid arguments. Expected [module_name]"}}
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

  defp extract_types(module) do
    result = Typespec.get_types(module)
    
    case result do
      types when is_list(types) and length(types) > 0 ->
        type_docs = get_type_docs(module)
        
        types
        |> Enum.filter(fn {kind, _} -> kind in [:type, :opaque] end)
        |> Enum.map(fn {_kind, {name, _, args}} = typedef ->
          type_info = format_type(typedef)
          arity = length(args)
          doc = Map.get(type_docs, {name, arity}, "")
          Map.put(type_info, :doc, doc)
        end)
        |> Enum.sort_by(& &1.name)
        
      _ ->
        []
    end
  end

  defp extract_specs(module) do
    result = Typespec.get_specs(module)
    
    case result do
      specs when is_list(specs) and length(specs) > 0 ->
        function_docs = get_function_docs(module)
        
        specs
        |> Enum.map(fn {{name, arity}, _spec_ast} = spec ->
          spec_info = format_spec(spec)
          doc = Map.get(function_docs, {name, arity}, "")
          Map.put(spec_info, :doc, doc)
        end)
        |> Enum.sort_by(& &1.name)
        
      _ ->
        []
    end
  end
  
  defp get_function_docs(module) do
    case NormalizedCode.get_docs(module, :docs) do
      docs when is_list(docs) ->
        docs
        |> Enum.filter(fn doc_entry ->
          case doc_entry do
            {{:function, _, _}, _, _, _, _} -> true
            _ -> false
          end
        end)
        |> Enum.map(fn {{:function, name, arity}, _, _, doc, _} ->
          {{name, arity}, doc || ""}
        end)
        |> Map.new()
      _ ->
        %{}
    end
  end

  defp extract_callbacks(module) do
    result = Typespec.get_callbacks(module)
    
    case result do
      callbacks when is_list(callbacks) and length(callbacks) > 0 ->
        callback_docs = get_callback_docs(module)
        
        callbacks
        |> Enum.map(fn {{name, arity}, _spec_ast} = callback ->
          callback_info = format_callback(callback)
          doc = Map.get(callback_docs, {name, arity}, "")
          Map.put(callback_info, :doc, doc)
        end)
        |> Enum.sort_by(& &1.name)
        
      _ ->
        []
    end
  end
  
  defp get_callback_docs(module) do
    case NormalizedCode.get_docs(module, :callback_docs) do
      docs when is_list(docs) ->
        docs
        |> Enum.map(fn entry ->
          case entry do
            {{name, arity}, _, _, doc, _metadata} ->
              {{name, arity}, doc || ""}
            {{:type, _, _}, _, _, _, _} ->
              # Skip callback types
              nil
            _ ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()
      _ ->
        %{}
    end
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
    spec = TypeInfo.format_type_spec(typedef, line_length: 75)
    
    %{
      name: "#{name}/#{arity}",
      kind: kind,
      signature: signature,
      spec: spec
    }
  end

  defp format_spec({{name, arity}, specs}) do
    signature = "#{name}/#{arity}"
    
    # Format all specs for this function
    formatted_specs = 
      specs
      |> Enum.map(fn spec_ast ->
        try do
          # Convert from Erlang AST to Elixir AST
          quoted = Typespec.spec_to_quoted(name, spec_ast)
          TypeInfo.format_type_spec_ast(quoted, :spec, line_length: 75)
        rescue
          _ -> "@spec #{name}/#{arity}"
        end
      end)
      |> Enum.join("\n")
    
    %{
      name: signature,
      specs: formatted_specs
    }
  end

  defp format_callback({{name, arity}, specs}) do
    signature = "#{name}/#{arity}"
    
    # Format all callback specs
    formatted_specs = 
      specs
      |> Enum.map(fn spec_ast ->
        try do
          # Convert from Erlang AST to Elixir AST
          quoted = Typespec.spec_to_quoted(name, spec_ast)
          TypeInfo.format_type_spec_ast(quoted, :callback, line_length: 75)
        rescue
          _ -> "@callback #{name}/#{arity}"
        end
      end)
      |> Enum.join("\n")
    
    %{
      name: signature,
      specs: formatted_specs
    }
  end

  defp format_dialyzer_contract({_file, line, {_mod, fun, arity}, success_typing, _is_macro}) do
    %{
      name: "#{fun}/#{arity}",
      line: line,
      contract: List.to_string(success_typing)
    }
  end

  defp format_type_signature(name, args) do
    arg_names = Enum.map_join(args, ", ", fn {_, _, name} -> Atom.to_string(name) end)
    "#{name}(#{arg_names})"
  end


  defp get_type_docs(module) do
    case NormalizedCode.get_docs(module, :type_docs) do
      docs when is_list(docs) ->
        Map.new(docs, fn {{name, arity}, _, _, doc, _metadata} ->
          {{name, arity}, doc || ""}
        end)
      _ ->
        %{}
    end
  end
end
