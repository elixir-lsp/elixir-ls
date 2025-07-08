defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmImplementationFinder do
  @moduledoc """
  This module implements a custom command for finding implementations of behaviours,
  protocols, and defdelegate targets. It accepts a string-based symbol identifier
  and returns the implementations in a format optimized for LLM consumption.
  """

  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Behaviours

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([symbol], _state) when is_binary(symbol) do
    try do
      case parse_symbol(symbol) do
        {:ok, type, parsed} ->
          case find_implementations(type, parsed) do
            {:ok, implementations} ->
              # Convert locations to detailed implementation info
              formatted_implementations = 
                implementations
                |> Enum.map(&format_implementation/1)
                |> Enum.reject(&is_nil/1)

              {:ok, %{implementations: formatted_implementations}}

            {:error, reason} ->
              {:ok, %{error: "Failed to find implementations: #{reason}"}}
          end

        {:error, reason} ->
          {:ok, %{error: "Invalid symbol format: #{reason}"}}
      end
    rescue
      error ->
        Logger.error("Error in llmImplementationFinder: #{inspect(error)}")
        {:ok, %{error: "Internal error: #{Exception.message(error)}"}}
    end
  end

  def execute(_args, _state) do
    {:ok, %{error: "Invalid arguments: expected [symbol_string]"}}
  end

  # Parse symbol strings like "MyBehaviour", "MyProtocol", "MyModule.callback_name", "MyModule.callback_name/2"
  defp parse_symbol(symbol) do
    cond do
      # Erlang module format :module
      String.starts_with?(symbol, ":") ->
        module_atom = String.slice(symbol, 1..-1//1) |> String.to_atom()
        {:ok, :erlang_module, module_atom}

      # Callback with arity: Module.callback/arity
      # TODO: unicode support in function names
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*\.[a-z_][a-z0-9_?!]*\/\d+$/) ->
        [module_fun, arity_str] = String.split(symbol, "/")
        [module_str, function_str] = String.split(module_fun, ".", parts: 2)

        module = Module.concat(String.split(module_str, "."))
        function = String.to_atom(function_str)
        arity = String.to_integer(arity_str)

        {:ok, :callback, {module, function, arity}}

      # Callback without arity: Module.callback
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*\.[a-z_][a-z0-9_?!]*$/) ->
        [module_str, function_str] = String.split(symbol, ".", parts: 2)

        module = Module.concat(String.split(module_str, "."))
        function = String.to_atom(function_str)

        {:ok, :callback, {module, function, nil}}

      # Module only: Module or Module.SubModule (behaviour or protocol)
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*$/) ->
        module = Module.concat(String.split(symbol, "."))
        {:ok, :module, module}

      true ->
        {:error, "Unrecognized symbol format. Expected: ModuleName, ModuleName.callback, or ModuleName.callback/arity"}
    end
  end

  defp find_implementations(:module, module) do
    # Check if it's a behaviour or protocol
    cond do
      # TODO: protocol is a behaviour, this needs to be reordered
      is_behaviour?(module) ->
        # Find all modules implementing this behaviour
        implementations = get_behaviour_implementations(module)
        locations = Enum.map(implementations, fn impl_module ->
          {impl_module, Location.find_mod_fun_source(impl_module, nil, nil)}
        end)
        {:ok, locations}

      is_protocol?(module) ->
        # Find all protocol implementations
        implementations = find_protocol_implementations(module)
        {:ok, implementations}

      true ->
        {:error, "#{inspect(module)} is not a behaviour or protocol"}
    end
  end

  defp find_implementations(:erlang_module, module) do
    find_implementations(:module, module)
  end

  defp find_implementations(:callback, {module, function, arity}) do
    # Find implementations of a specific callback
    cond do
      # TODO: protocol is a behaviour, this needs to be reordered
      is_behaviour?(module) ->
        implementations = get_behaviour_implementations(module)
        
        locations = Enum.flat_map(implementations, fn impl_module ->
          case find_callback_implementation(impl_module, function, arity) do
            nil -> []
            location -> [{impl_module, location}]
          end
        end)
        
        {:ok, locations}

      is_protocol?(module) ->
        # For protocol functions, find all implementations
        implementations = find_protocol_implementations(module)
        {:ok, implementations}

      true ->
        {:error, "#{module}.#{function} is not a callback or protocol function"}
    end
  end

  defp is_behaviour?(module) do
    # A module is a behaviour if:
    # 1. It exports behaviour_info/1, or
    # 2. It has callback definitions
    Code.ensure_loaded?(module) and
      (function_exported?(module, :behaviour_info, 1) or
       has_callback_attributes?(module))
  rescue
    _ -> false
  end

  # TODO: WTF?
  defp has_callback_attributes?(module) do
    # Check if module has @callback or @macrocallback attributes
    # This is a simplified check - in practice, we'd need to inspect the module's attributes
    # For now, we'll use a heuristic: check if common behaviours match
    module in [GenServer, Supervisor, Application, Agent, Task] or
      String.contains?(inspect(module), "Behaviour")
  rescue
    _ -> false
  end

  defp is_protocol?(module) do
    # Check if module defines __protocol__/1
    Code.ensure_loaded?(module) and function_exported?(module, :__protocol__, 1)
  rescue
    _ -> false
  end

  defp get_behaviour_implementations(behaviour) do
    # Try ElixirSense first
    case Behaviours.get_all_behaviour_implementations(behaviour) do
      [] ->
        # Fallback: search for modules that claim to implement this behaviour
        # TODO: this is redundant
        find_modules_with_behaviour(behaviour)
      implementations ->
        implementations
    end
  end

  defp find_modules_with_behaviour(behaviour) do
    # This is a simplified implementation
    # In a real implementation, we'd need to scan loaded modules or use metadata
    :code.all_loaded()
    |> Enum.filter(fn {module, _} ->
      Code.ensure_loaded?(module) and implements_behaviour?(module, behaviour)
    end)
    |> Enum.map(fn {module, _} -> module end)
  end

  defp implements_behaviour?(module, behaviour) do
    # Check if the module implements the behaviour
    module_behaviours = module.module_info(:attributes)[:behaviour] || []
    behaviour in module_behaviours
  rescue
    _ -> false
  end

  defp find_protocol_implementations(protocol) do
    # Get all implementations of a protocol
    try do
      # Use protocol consolidation info if available
      # TODO: this will not work, ElixirLS is not doing protocol consolidation
      implementations = protocol.__protocol__(:impls)
      
      case implementations do
        {:consolidated, impl_list} ->
          Enum.map(impl_list, fn impl ->
            impl_module = Module.concat([protocol, impl])
            {impl_module, Location.find_mod_fun_source(impl_module, nil, nil)}
          end)
          
        :not_consolidated ->
          # Try to find implementations by module naming convention
          find_protocol_implementations_by_convention(protocol)
      end
    rescue
      _ -> []
    end
  end

  defp find_protocol_implementations_by_convention(protocol) do
    # Look for modules matching Protocol.Type pattern
    prefix = "#{inspect(protocol)}."
    
    :code.all_loaded()
    |> Enum.filter(fn {module, _} ->
      module_str = inspect(module)
      String.starts_with?(module_str, prefix)
    end)
    |> Enum.map(fn {module, _} ->
      {module, Location.find_mod_fun_source(module, nil, nil)}
    end)
  end

  defp find_callback_implementation(module, function, arity) do
    # Try to find the specific function implementation
    Location.find_mod_fun_source(module, function, arity)
  end

  defp format_implementation({module, %Location{} = location}) do
    case read_implementation_source(location) do
      {:ok, source} ->
        %{
          module: inspect(module),
          file: location.file,
          line: location.line,
          column: location.column,
          type: Atom.to_string(location.type || :module),
          source: source
        }

      {:error, _reason} ->
        nil
    end
  end

  defp format_implementation({_module, nil}), do: nil

  defp read_implementation_source(%Location{
         file: file,
         line: start_line,
         column: start_column,
         end_line: end_line,
         end_column: end_column
       }) do
    read_source_at_location(file, start_line, start_column, end_line, end_column)
  end

  defp read_source_at_location(nil, _, _, _, _), do: {:error, "No file path"}

  defp read_source_at_location(file, start_line, start_column, end_line, end_column) do
    case File.read(file) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Extract text based on the Location range
        extracted_text =
          cond do
            # Single line extraction
            start_line == end_line ->
              line = Enum.at(lines, start_line - 1, "")
              # Use the full line if columns are nil
              if start_column && end_column do
                String.slice(line, (start_column - 1)..(end_column - 2))
              else
                line
              end

            # Multi-line extraction
            true ->
              # Get the lines in the range (convert from 1-based to 0-based indexing)
              extracted_lines = Enum.slice(lines, (start_line - 1)..(end_line - 1))

              # Apply column restrictions if available
              extracted_lines =
                extracted_lines
                |> Enum.with_index()
                |> Enum.map(fn {line, idx} ->
                  cond do
                    # First line - slice from start_column to end
                    idx == 0 && start_column ->
                      String.slice(line, (start_column - 1)..-1//1)

                    # Last line - slice from beginning to end_column
                    idx == length(extracted_lines) - 1 && end_column ->
                      String.slice(line, 0..(end_column - 2)//1)

                    # Middle lines - keep full line
                    true ->
                      line
                  end
                end)

              Enum.join(extracted_lines, "\n")
          end

        # For implementations, try to get the full module or function definition
        full_implementation = 
          if start_column == nil and end_column == nil do
            # Read the entire module/function
            extract_full_implementation(lines, start_line - 1)
          else
            extracted_text
          end

        {:ok, full_implementation}

      {:error, reason} ->
        {:error, "Cannot read file #{file}: #{reason}"}
    end
  end

  # Extract full module or function implementation
  defp extract_full_implementation(lines, start_idx) do
    # For now, just return lines starting from the given index
    # In a more sophisticated implementation, we could parse to find the end
    lines
    |> Enum.drop(start_idx)
    |> Enum.take(50)  # Reasonable limit for display
    |> Enum.join("\n")
  end
end
