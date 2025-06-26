defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinition do
  @moduledoc """
  This module implements a custom command for finding symbol definitions
  optimized for LLM consumption. It returns the source code of the definition.
  """

  alias ElixirLS.LanguageServer.Location

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([symbol], state) when is_binary(symbol) do
    try do
      # Parse the symbol to determine type
      case parse_symbol(symbol) do
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

            {:error, reason} ->
              {:ok, %{error: "Definition not found: #{reason}"}}
          end

        {:error, reason} ->
          {:ok, %{error: "Invalid symbol format: #{reason}"}}
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

  # Parse symbol strings like "MyModule", "MyModule.my_function", "MyModule.my_function/2"
  defp parse_symbol(symbol) do
    cond do
      # Erlang module format :module
      String.starts_with?(symbol, ":") ->
        module_atom = String.slice(symbol, 1..-1) |> String.to_atom()
        {:ok, :erlang_module, module_atom}

      # Function with arity: Module.function/arity
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*\.[a-z_][a-z0-9_?!]*\/\d+$/) ->
        [module_fun, arity_str] = String.split(symbol, "/")
        [module_str, function_str] = String.split(module_fun, ".", parts: 2)

        module = Module.concat([module_str])
        function = String.to_atom(function_str)
        arity = String.to_integer(arity_str)

        {:ok, :function, {module, function, arity}}

      # Function without arity: Module.function
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*\.[a-z_][a-z0-9_?!]*$/) ->
        [module_str, function_str] = String.split(symbol, ".", parts: 2)

        module = Module.concat([module_str])
        function = String.to_atom(function_str)

        {:ok, :function, {module, function, nil}}

      # Module only: Module or Module.SubModule
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*$/) ->
        module = Module.concat(String.split(symbol, "."))
        {:ok, :module, module}

      true ->
        {:error, "Unrecognized symbol format"}
    end
  end

  defp find_definition(:module, module, _state) do
    # Try to find module definition
    case Location.find_mod_fun_source(module, nil, nil) do
      %Location{} = location -> {:ok, location}
      _ -> {:error, "Module #{inspect(module)} not found"}
    end
  end

  defp find_definition(:erlang_module, module, _state) do
    # Try to find Erlang module
    case Location.find_mod_fun_source(module, nil, nil) do
      %Location{} = location -> {:ok, location}
      _ -> {:error, "Erlang module #{inspect(module)} not found"}
    end
  end

  defp find_definition(:function, {module, function, arity}, _state) do
    # Try to find function definition
    case Location.find_mod_fun_source(module, function, arity) do
      %Location{} = location ->
        {:ok, location}

      _ ->
        # If arity is nil, try to find any matching function
        if arity == nil do
          case find_any_arity(module, function) do
            {:ok, location} -> {:ok, location}
            _ -> {:error, "Function #{module}.#{function} not found"}
          end
        else
          {:error, "Function #{module}.#{function}/#{arity} not found"}
        end
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

    search_start..(start_idx - 1)
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
