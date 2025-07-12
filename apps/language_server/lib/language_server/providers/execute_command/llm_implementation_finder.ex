defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmImplementationFinder do
  @moduledoc """
  This module implements a custom command for finding implementations of behaviours,
  protocols, and defdelegate targets. It accepts a string-based symbol identifier
  and returns the implementations in a format optimized for LLM consumption.
  """

  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Behaviours
  alias ElixirSense.Core.Introspection
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([symbol], _state) when is_binary(symbol) do
    try do
      case SymbolParser.parse(symbol) do
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
          {:ok, %{error: reason}}
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


  defp find_implementations(:module, module) do
    # Check if it's a protocol first, then behaviour (protocol is a type of behaviour)
    case Introspection.get_module_subtype(module) do
      :protocol ->
        # Find all protocol implementations
        implementations = get_behaviour_implementations(module)
        locations = Enum.map(implementations, fn impl_module ->
          {impl_module, Location.find_mod_fun_source(impl_module, nil, nil)}
        end)
        {:ok, locations}

      :behaviour ->
        # Find all modules implementing this behaviour
        implementations = get_behaviour_implementations(module)
        locations = Enum.map(implementations, fn impl_module ->
          {impl_module, Location.find_mod_fun_source(impl_module, nil, nil)}
        end)
        {:ok, locations}

      _ ->
        {:error, "#{inspect(module)} is not a behaviour or protocol"}
    end
  end

  defp find_implementations(:local_call, {function, arity}) do
    # Local calls don't have implementations in the context of behaviours/protocols
    {:error, "Local call #{function}/#{arity || "?"} - no implementations found"}
  end

  defp find_implementations(:remote_call, {module, function, arity}) do
    # For implementation finder, we treat functions as potential callbacks
    # Find implementations of a specific callback
    case Introspection.get_module_subtype(module) do
      subtype when subtype in [:protocol, :behaviour] ->
        implementations = get_behaviour_implementations(module)
        
        locations = Enum.flat_map(implementations, fn impl_module ->
          case find_callback_implementation(impl_module, function, arity) do
            nil -> []
            location -> [{impl_module, location}]
          end
        end)
        
        {:ok, locations}

      _ ->
        {:error, "#{module}.#{function}/#{arity || "?"} is not a callback or protocol function"}
    end
  end

  defp find_implementations(:attribute, attribute) do
    {:error, "Module attribute @#{attribute} - attributes don't have implementations"}
  end


  defp get_behaviour_implementations(behaviour) do
    # Use ElixirSense Behaviours module which handles both behaviour and protocol implementations
    Behaviours.get_all_behaviour_implementations(behaviour)
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
