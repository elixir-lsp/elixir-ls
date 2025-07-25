defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinition do
  @moduledoc """
  This module implements a custom command for finding symbol definitions
  optimized for LLM consumption. It returns the source code of the definition.
  """

  alias ElixirLS.LanguageServer.Location
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser
  alias ElixirSense.Core.BuiltinTypes

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([symbol], state) when is_binary(symbol) do
    try do
      # Parse the symbol to determine type
      case SymbolParser.parse(symbol) do
        {:ok, type, parsed} ->
          # Find the definition
          case find_definition(type, parsed, state) do
            {:ok, %Location{} = location} ->
              # Read the definition source code
              case read_definition_source(location) do
                {:ok, source} ->
                  {:ok, %{definition: source}}

                {:error, reason} ->
                  {:ok, %{error: "Failed to read source: #{reason}"}}
              end

            {:ok, %{definition: _} = result} ->
              # Already formatted result (e.g., from builtin types)
              {:ok, result}

            {:error, reason} ->
              {:ok, %{error: "Definition not found: #{reason}"}}
          end

        {:error, reason} ->
          {:ok, %{error: reason}}
      end
    rescue
      error ->
        Logger.error("Error in llmDefinition: #{inspect(error)}")
        {:ok, %{error: "Internal error: #{Exception.message(error)}"}}
    end
  end

  def execute(_args, _state) do
    {:ok, %{error: "Invalid arguments: expected [symbol_string]"}}
  end

  defp find_definition(:module, module, _state) do
    # Try to find module definition
    case Location.find_mod_fun_source(module, nil, nil) do
      %Location{} = location -> {:ok, location}
      _ -> {:error, "Module #{inspect(module)} not found"}
    end
  end

  defp find_definition(:local_call, {function, arity}, _state) do
    # For local calls, try Kernel import first, then builtin type
    # Try Kernel function/macro first
    case Location.find_mod_fun_source(Kernel, function, arity) do
      %Location{} = location ->
        {:ok, location}

      _ ->
        # If arity is nil, try to find any matching Kernel function
        if arity == nil do
          case find_any_arity(Kernel, function) do
            {:ok, location} -> {:ok, location}
            _ -> try_builtin_type(function)
          end
        else
          try_builtin_type(function)
        end
    end
  end

  defp find_definition(:remote_call, {module, function, arity}, _state) do
    # For remote calls, try function/macro first, then type
    # Try function/macro first
    case Location.find_mod_fun_source(module, function, arity) do
      %Location{} = location ->
        {:ok, location}

      _ ->
        # If arity is nil, try to find any matching function
        if arity == nil do
          case find_any_arity(module, function) do
            {:ok, location} -> {:ok, location}
            _ -> try_type_definition(module, function)
          end
        else
          try_type_definition(module, function)
        end
    end
  end

  defp find_definition(:attribute, attribute, _state) do
    # Module attributes don't have specific definitions, return info about the attribute
    {:error, "Module attribute @#{attribute} - attributes are defined within modules"}
  end

  defp try_builtin_type(function) do
    # Try to find builtin type definitions using ElixirSense.Core.BuiltinTypes
    if BuiltinTypes.builtin_type?(function) do
      # Get the documentation for the builtin type
      doc = BuiltinTypes.get_builtin_type_doc(function)

      # Get type info to check if it has parameters
      type_info = BuiltinTypes.get_builtin_type_info(function)

      # Create a comprehensive builtin type definition
      type_definitions =
        type_info
        |> Enum.map(fn info ->
          signature = Map.get(info, :signature, "#{function}()")
          params = Map.get(info, :params, [])
          spec = Map.get(info, :spec)

          spec_string =
            if spec do
              try do
                "@type #{Macro.to_string(spec)}"
              rescue
                _ -> "@type #{signature}"
              end
            else
              "@type #{signature}"
            end

          param_docs =
            if params != [] do
              param_list = Enum.map(params, &Atom.to_string/1) |> Enum.join(", ")
              "\n\nParameters: #{param_list}"
            else
              ""
            end

          """
          #{spec_string}

          #{doc}#{param_docs}
          """
        end)
        |> Enum.join("\n---\n")

      result = """
      # Builtin type #{function}() - Elixir built-in type

      #{type_definitions}

      For more information, see the Elixir documentation on basic types and built-in types.
      """

      {:ok, %{definition: result}}
    else
      {:error, "Local call #{function} not found in Kernel and not a builtin type"}
    end
  end

  defp try_type_definition(module, type_name) do
    # For types, try to find the module and look for type definitions there
    case Location.find_mod_fun_source(module, nil, nil) do
      %Location{} = location ->
        # Return the module location - the type definition will be found within the module
        {:ok, location}

      _ ->
        {:error, "Type #{module}.#{type_name} not found - module #{inspect(module)} not found"}
    end
  end

  defp find_any_arity(module, function) do
    # Try common arities
    Enum.find_value(0..10, fn arity ->
      case Location.find_mod_fun_source(module, function, arity) do
        %Location{} = location -> {:ok, location}
        _ -> nil
      end
    end) || {:error, :not_found}
  end

  defp read_definition_source(%Location{
         file: file,
         line: start_line,
         column: start_column,
         end_line: end_line,
         end_column: end_column
       }) do
    case File.read(file) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Extract text based on the Location range
        extracted_text =
          cond do
            # Single line extraction
            start_line == end_line ->
              line = Enum.at(lines, start_line - 1, "")
              # Use the full line if columns are nil, otherwise slice
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

        # Look for additional context (e.g., @doc, @spec) before the definition
        context_lines = extract_context(lines, start_line - 1)

        # Combine context and definition
        full_definition =
          if context_lines != [] do
            Enum.join(context_lines ++ [extracted_text], "\n")
          else
            extracted_text
          end

        # Format the result
        result = """
        # Definition found in #{file}:#{start_line}

        #{full_definition}
        """

        {:ok, result}

      {:error, reason} ->
        {:error, "Cannot read file #{file}: #{reason}"}
    end
  end

  # Extract @doc, @spec, and other attributes before the definition
  defp extract_context(lines, start_idx) do
    # Look backwards for related attributes (up to 20 lines)
    search_start = max(0, start_idx - 20)

    search_start..(start_idx - 1)//1
    |> Enum.map(fn idx -> Enum.at(lines, idx, "") end)
    |> Enum.reverse()
    |> Enum.take_while(fn line ->
      trimmed = String.trim(line)
      # Continue collecting if it's an attribute, comment, or empty line
      String.starts_with?(trimmed, "@") ||
        String.starts_with?(trimmed, "#") ||
        trimmed == ""
    end)
    |> Enum.reverse()
    |> Enum.drop_while(fn line -> String.trim(line) == "" end)
  end
end
